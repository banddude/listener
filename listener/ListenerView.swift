//
//  ListenerView.swift
//  listener
//
//  Created by Mike Shaffer on 5/23/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ListenerView: View {
    @StateObject private var audioRecorder = VoiceActivityRecorder()
    @StateObject private var speakerIDService = SpeakerIDService()
    @State private var selectedTranscriptionResult: TranscriptionResult?
    @State private var selectedRecording: URL?
    @State private var transcribedRecordings: Set<URL> = []
    @State private var currentlyTranscribing: URL?
    @State private var savedTranscriptions: [URL: TranscriptionResult] = [:]
    @State private var showingUploadView = false
    @State private var recordingToUpload: URL?
    
    var body: some View {
        ScrollView {
            mainContent
        }
        .background(Color.gray.opacity(0.1))
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
        .sheet(isPresented: $showingUploadView) {
            if let recording = recordingToUpload {
                UploadView(
                    speakerIDService: speakerIDService,
                    preselectedFile: recording
                )
            }
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 16) {
            headerSection
            statusCard
            quickStats
            mainControlButton
            recordingsSection
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        HStack {
            Text("Listener")
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private var statusCard: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(audioRecorder.isListening ? .green : .red)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(audioRecorder.isListening ? "Listening" : "Stopped")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if audioRecorder.isSpeechDetected {
                    Text("Speech Detected")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else if audioRecorder.isRecordingClip {
                    Text("Recording - \(String(format: "%.1f", audioRecorder.currentClipDuration))s")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text(audioRecorder.isListening ? "Ready" : "Tap to start")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Simple threshold control
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(audioRecorder.silenceThreshold))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $audioRecorder.silenceThreshold, in: 1...60, step: 1.0)
                    .frame(width: 80)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
    
    private var quickStats: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("\(audioRecorder.clipsCount)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("clips")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .frame(height: 16)
            
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.caption)
                    .foregroundColor(.green)
                Text("\(transcribedRecordings.count)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("transcribed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private var mainControlButton: some View {
        Button(action: {
            if audioRecorder.isListening {
                audioRecorder.stopListening()
            } else {
                audioRecorder.startListening()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: audioRecorder.isListening ? "stop.fill" : "play.fill")
                    .font(.subheadline)
                
                Text(audioRecorder.isListening ? "Stop" : "Start")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(audioRecorder.isListening ? Color.red : Color.green)
            .cornerRadius(10)
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var statusMessages: some View {
        if !audioRecorder.statusMessage.isEmpty || !audioRecorder.errorMessage.isEmpty {
            VStack(spacing: 6) {
                if !audioRecorder.statusMessage.isEmpty {
                    Text(audioRecorder.statusMessage)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                }
                
                if !audioRecorder.errorMessage.isEmpty {
                    Text(audioRecorder.errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var recordingsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Recordings")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                
                Button(action: {
                    audioRecorder.refreshRecordings()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            if audioRecorder.savedRecordings.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "waveform.slash")
                        .font(.title2)
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Text("No recordings yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(audioRecorder.savedRecordings, id: \.lastPathComponent) { recording in
                        CompactRecordingRow(
                            recording: recording,
                            isPlaying: audioRecorder.currentlyPlayingURL == recording,
                            isTranscribing: currentlyTranscribing == recording,
                            isTranscribed: transcribedRecordings.contains(recording),
                            onPlay: { audioRecorder.playRecording(recording) },
                            onStop: { audioRecorder.stopPlayback() },
                            onTranscribe: { transcribeRecording(recording) },
                            onViewTranscription: { viewTranscription(recording) },
                            onShare: { shareRecording(recording) },
                            onUpload: { uploadRecording(recording) },
                            onDelete: { 
                                if let index = audioRecorder.savedRecordings.firstIndex(of: recording) {
                                    deleteRecordings(at: IndexSet(integer: index))
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Functions
    
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
            do {
                // Upload to backend and get speaker ID processing
                let response = try await speakerIDService.uploadConversation(
                    audioFileURL: recording,
                    displayName: recording.lastPathComponent.replacingOccurrences(of: ".wav", with: "")
                )
                
                // Try to wait for backend processing, but fall back to local transcription
                do {
                    let conversationDetail = try await waitForProcessingCompletion(
                        conversationId: response.conversation_id
                    )
                    
                    // Convert backend response to local TranscriptionResult format
                    let result = convertToTranscriptionResult(conversationDetail)
                    
                    await MainActor.run {
                        self.savedTranscriptions[recording] = result
                        self.transcribedRecordings.insert(recording)
                        self.currentlyTranscribing = nil
                    }
                    print("✅ Backend processing completed successfully")
                    return
                } catch {
                    print("⚠️ Backend processing failed - processing pipeline is broken")
                    
                    // Create a simple result showing the backend is broken
                    let fallbackSummary = ConversationSummary(
                        title: "Backend Error",
                        keyPoints: ["Backend processing pipeline is broken"],
                        actionItems: ["Contact backend administrator"],
                        participants: [],
                        duration: "0 seconds",
                        topics: ["Backend Error"]
                    )
                    
                    let fallbackResult = TranscriptionResult(
                        conversation: [ConversationSegment(
                            timestamp: "00:00:00",
                            speaker: "System",
                            text: "Backend processing failed. Upload successful but transcription pipeline is broken."
                        )],
                        summary: fallbackSummary
                    )
                    
                    await MainActor.run {
                        self.savedTranscriptions[recording] = fallbackResult
                        self.transcribedRecordings.insert(recording)
                        self.currentlyTranscribing = nil
                    }
                }
            } catch {
                await MainActor.run {
                    currentlyTranscribing = nil
                    print("Failed to process with backend: \(error)")
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
    
    private func shareRecording(_ recording: URL) {
        audioRecorder.shareRecording(recording)
    }
    
    private func uploadRecording(_ recording: URL) {
        recordingToUpload = recording
        showingUploadView = true
    }
    
    private func waitForProcessingCompletion(conversationId: String) async throws -> ConversationDetail {
        let maxAttempts = 30 // Maximum 5 minutes (30 * 10 seconds)
        var attempts = 0
        
        while attempts < maxAttempts {
            attempts += 1
            
            // Try to get conversation details
            do {
                let details = try await speakerIDService.getConversationDetails(conversationId: conversationId)
                
                // Check if processing is complete (has utterances)
                if !details.utterances.isEmpty {
                    print("✅ Processing complete! Found \(details.utterances.count) utterances")
                    return details
                }
                
                print("⏳ Processing still in progress... attempt \(attempts)/\(maxAttempts)")
            } catch {
                print("⚠️ Error checking processing status: \(error)")
            }
            
            // Wait 10 seconds before trying again
            try await Task.sleep(nanoseconds: 10_000_000_000)
        }
        
        throw SpeakerIDError.uploadFailed
    }
    
    private func convertToTranscriptionResult(_ conversationDetail: ConversationDetail) -> TranscriptionResult {
        // Convert utterances to conversation segments
        let segments = conversationDetail.utterances.map { utterance in
            ConversationSegment(
                timestamp: utterance.start_time,
                speaker: utterance.speaker_name,
                text: utterance.text
            )
        }
        
        // Extract unique speakers
        let speakers = Array(Set(conversationDetail.utterances.map { $0.speaker_name }))
        
        // Create a summary from the conversation
        let summary = ConversationSummary(
            title: conversationDetail.display_name ?? "Speaker ID Conversation",
            keyPoints: ["Conversation processed with speaker identification"],
            actionItems: [],
            participants: speakers,
            duration: "\(conversationDetail.duration_seconds ?? 0) seconds",
            topics: ["Speaker-identified conversation"]
        )
        
        return TranscriptionResult(conversation: segments, summary: summary)
    }
}

// MARK: - Compact Recording Row Component

struct CompactRecordingRow: View {
    let recording: URL
    let isPlaying: Bool
    let isTranscribing: Bool
    let isTranscribed: Bool
    let onPlay: () -> Void
    let onStop: () -> Void
    let onTranscribe: () -> Void
    let onViewTranscription: () -> Void
    let onShare: () -> Void
    let onUpload: () -> Void
    let onDelete: () -> Void
    
    private var fileName: String {
        recording.lastPathComponent.replacingOccurrences(of: ".wav", with: "")
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        if let creationDate = try? recording.resourceValues(forKeys: [.creationDateKey]).creationDate {
            return formatter.string(from: creationDate)
        }
        return ""
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Status dot
            Circle()
                .fill(isTranscribed ? .green : .gray.opacity(0.3))
                .frame(width: 8, height: 8)
            
            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(fileName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if !timeString.isEmpty {
                    Text(timeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                if isTranscribing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button(action: isPlaying ? onStop : onPlay) {
                        Image(systemName: isPlaying ? "pause" : "play")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: isTranscribed ? onViewTranscription : onTranscribe) {
                        Image(systemName: isTranscribed ? "doc.text" : "icloud.and.arrow.up")
                            .font(.caption)
                            .foregroundColor(isTranscribed ? .green : .purple)
                    }
                    
                    Menu {
                        Button("Upload", action: onUpload)
                        Button("Share", action: onShare)
                        Divider()
                        Button("Delete", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

#Preview {
    ListenerView()
} 