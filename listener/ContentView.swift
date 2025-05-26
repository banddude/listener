//
//  ContentView.swift
//  listener
//
//  Created by Mike Shaffer on 5/23/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @StateObject private var audioRecorder = VoiceActivityRecorder()
    @StateObject private var summarizationService = SummarizationService()
    @State private var selectedTranscriptionResult: TranscriptionResult?
    @State private var selectedRecording: URL?
    @State private var transcribedRecordings: Set<URL> = []
    @State private var currentlyTranscribing: URL?
    @State private var savedTranscriptions: [URL: TranscriptionResult] = [:]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Voice Listener")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Status indicator
                HStack {
                    Circle()
                        .fill(audioRecorder.isListening ? .green : .red)
                        .frame(width: 20, height: 20)
                    Text(audioRecorder.isListening ? "Listening" : "Stopped")
                        .font(.headline)
                }
                
                // Speech detection indicator
                if audioRecorder.isSpeechDetected {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.blue)
                        Text("Speech Detected")
                            .foregroundColor(.blue)
                            .font(.subheadline)
                    }
                }
                
                // Recording status
                if audioRecorder.isRecordingClip {
                    VStack {
                        Text("Recording Clip")
                            .foregroundColor(.red)
                            .font(.headline)
                        Text("Duration: \(String(format: "%.1f", audioRecorder.currentClipDuration))s")
                            .font(.caption)
                    }
                }
                
                // Stats
                HStack(spacing: 30) {
                    VStack {
                        Text("\(audioRecorder.clipsCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Clips Saved")
                            .font(.caption)
                    }
                }
                
                // Silence threshold adjustment
                VStack(spacing: 8) {
                    Stepper(value: $audioRecorder.silenceThreshold, in: 1...60, step: 1.0) {
                        Text("Silence Threshold: \(String(format: "%.0f", audioRecorder.silenceThreshold))s")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                .padding(.horizontal)
                
                // Control buttons
                Button(audioRecorder.isListening ? "Stop" : "Start Listening") {
                    if audioRecorder.isListening {
                        audioRecorder.stopListening()
                    } else {
                        audioRecorder.startListening()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(audioRecorder.isListening ? .red : .green)
                
                // Status message
                Text(audioRecorder.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Error message
                if !audioRecorder.errorMessage.isEmpty {
                    Text(audioRecorder.errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Divider()
                
                // Recordings list
                VStack(alignment: .leading) {
                    HStack {
                        Text("Saved Recordings")
                            .font(.headline)
                        Spacer()
                        Button("Refresh") {
                            audioRecorder.refreshRecordings()
                        }
                        .font(.caption)
                    }
                    
                    if audioRecorder.savedRecordings.isEmpty {
                        Text("No recordings yet")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        List {
                            ForEach(audioRecorder.savedRecordings, id: \.lastPathComponent) { recording in
                                RecordingRow(
                                    recording: recording,
                                    isPlaying: audioRecorder.currentlyPlayingURL == recording,
                                    isTranscribing: currentlyTranscribing == recording,
                                    isTranscribed: transcribedRecordings.contains(recording),
                                    onPlay: { audioRecorder.playRecording(recording) },
                                    onStop: { audioRecorder.stopPlayback() },
                                    onTranscribe: { transcribeRecording(recording) },
                                    onViewTranscription: { viewTranscription(recording) }
                                )
                            }
                            .onDelete(perform: deleteRecordings)
                        }
                        .listStyle(PlainListStyle())
                        .frame(maxHeight: 300)
                    }
                }
                
                Spacer()
            }
            .padding()
            .onAppear {
                audioRecorder.requestPermissions()
                audioRecorder.refreshRecordings()
            }
            .onChange(of: audioRecorder.savedRecordings) {
                loadSavedTranscriptions()
            }
            .sheet(item: $selectedTranscriptionResult) { result in
                if let recording = selectedRecording {
                    TranscriptionDetailView(
                        recording: recording,
                        transcriptionResult: result
                    )
                } else {
                    Text("Error: Recording not found")
                        .padding()
                }
            }
        }
    }
    
    private func deleteRecordings(at offsets: IndexSet) {
        for index in offsets {
            let recording = audioRecorder.savedRecordings[index]
            audioRecorder.deleteRecording(recording)
        }
    }
    
    private func transcribeRecording(_ recording: URL) {
        currentlyTranscribing = recording
        selectedRecording = recording
        
        Task {
            if let result = await summarizationService.transcribeAndSummarize(audioFileURL: recording) {
                await MainActor.run {
                    currentlyTranscribing = nil
                    transcribedRecordings.insert(recording)
                    savedTranscriptions[recording] = result
                    saveTranscriptionToDisk(result, for: recording)
                    selectedTranscriptionResult = result
                }
            } else {
                await MainActor.run {
                    currentlyTranscribing = nil
                }
            }
        }
    }
    
    private func viewTranscription(_ recording: URL) {
        selectedRecording = recording
        selectedTranscriptionResult = savedTranscriptions[recording]
    }
    
    private func saveTranscriptionToDisk(_ result: TranscriptionResult, for recording: URL) {
        let transcriptionURL = transcriptionFileURL(for: recording)
        
        do {
            let data = try JSONEncoder().encode(result)
            try data.write(to: transcriptionURL)
        } catch {
            print("Failed to save transcription: \(error)")
        }
    }
    
    private func loadSavedTranscriptions() {
        print("Loading transcriptions for \(audioRecorder.savedRecordings.count) recordings")
        for recording in audioRecorder.savedRecordings {
            let transcriptionURL = transcriptionFileURL(for: recording)
            print("Checking for transcription: \(transcriptionURL.path)")
            
            if FileManager.default.fileExists(atPath: transcriptionURL.path) {
                do {
                    let data = try Data(contentsOf: transcriptionURL)
                    let result = try JSONDecoder().decode(TranscriptionResult.self, from: data)
                    savedTranscriptions[recording] = result
                    transcribedRecordings.insert(recording)
                    print("Loaded transcription for: \(recording.lastPathComponent)")
                } catch {
                    print("Failed to load transcription for \(recording.lastPathComponent): \(error)")
                }
            } else {
                print("No transcription file found at: \(transcriptionURL.path)")
            }
        }
        print("Loaded \(savedTranscriptions.count) transcriptions")
    }
    
    private func transcriptionFileURL(for recording: URL) -> URL {
        let recordingName = recording.deletingPathExtension().lastPathComponent
        return recording.deletingLastPathComponent().appendingPathComponent("\(recordingName)_transcription.json")
    }
}

struct RecordingRow: View {
    let recording: URL
    let isPlaying: Bool
    let isTranscribing: Bool
    let isTranscribed: Bool
    let onPlay: () -> Void
    let onStop: () -> Void
    let onTranscribe: () -> Void
    let onViewTranscription: () -> Void
    
    private var fileName: String {
        recording.lastPathComponent.replacingOccurrences(of: ".wav", with: "")
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        
        if let creationDate = try? recording.resourceValues(forKeys: [.creationDateKey]).creationDate {
            return formatter.string(from: creationDate)
        }
        return "Unknown"
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(fileName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(dateString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: isPlaying ? onStop : onPlay) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .foregroundColor(isPlaying ? .red : .blue)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: isTranscribed ? onViewTranscription : onTranscribe) {
                    if isTranscribing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if isTranscribed {
                        Image(systemName: "doc.text")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "icloud.and.arrow.up")
                            .foregroundColor(.purple)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isTranscribing)
                
                Button(action: { shareRecording(recording) }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}

#if canImport(UIKit)
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // Configure for iPad popover presentation
        if UIDevice.current.userInterfaceIdiom == .pad {
            controller.modalPresentationStyle = .popover
            if let popover = controller.popoverPresentationController {
                popover.sourceRect = CGRect(x: 0, y: 0, width: 1, height: 1)
                popover.permittedArrowDirections = []
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
