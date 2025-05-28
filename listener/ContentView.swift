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
    @StateObject private var speakerIDService = SpeakerIDService()
    @State private var selectedTranscriptionResult: TranscriptionResult?
    @State private var selectedRecording: URL?
    @State private var transcribedRecordings: Set<URL> = []
    @State private var currentlyTranscribing: URL?
    @State private var savedTranscriptions: [URL: TranscriptionResult] = [:]
    @State private var showingUploadView = false
    @State private var recordingToUpload: URL?
    
    var body: some View {
        NavigationView {
            ScrollView {
                mainContent
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
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
        VStack(spacing: 24) {
            headerSection
            statusCard
            quickStats
            settingsCard
            mainControlButton
            statusMessages
            recordingsSection
            
            // Bottom padding for scroll
            Color.clear.frame(height: 20)
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Listener Pro")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("AI-Powered Voice Recording")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
    
    private var statusCard: some View {
        VStack(spacing: 16) {
            // Main Status Indicator
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(audioRecorder.isListening ? 
                              Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .fill(audioRecorder.isListening ? .green : .red)
                        .frame(width: 24, height: 24)
                        .scaleEffect(audioRecorder.isListening ? 1.0 : 0.8)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), 
                                 value: audioRecorder.isListening)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(audioRecorder.isListening ? "Listening" : "Stopped")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(audioRecorder.isListening ? .green : .primary)
                    
                    Text(audioRecorder.isListening ? 
                        "Ready to capture conversations" : "Tap to start recording")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Active Recording Indicator
            if audioRecorder.isSpeechDetected || audioRecorder.isRecordingClip {
                VStack(spacing: 8) {
                    if audioRecorder.isSpeechDetected {
                        HStack(spacing: 8) {
                            Image(systemName: "waveform")
                                .foregroundColor(.blue)
                                .symbolEffect(.pulse)
                            Text("Speech Detected")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    if audioRecorder.isRecordingClip {
                        VStack(spacing: 4) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(1.5)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), 
                                             value: audioRecorder.isRecordingClip)
                                
                                Text("Recording")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                            }
                            
                            Text("\(String(format: "%.1f", audioRecorder.currentClipDuration))s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private var quickStats: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Clips Saved",
                value: "\(audioRecorder.clipsCount)",
                icon: "waveform.and.mic",
                color: .blue
            )
            
            StatCard(
                title: "Transcribed",
                value: "\(transcribedRecordings.count)",
                icon: "doc.text",
                color: .green
            )
        }
        .padding(.horizontal)
    }
    
    private var settingsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.blue)
                Text("Recording Settings")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("Silence Threshold")
                        .font(.subheadline)
                    Spacer()
                    Text("\(String(format: "%.0f", audioRecorder.silenceThreshold))s")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                
                Slider(value: $audioRecorder.silenceThreshold, in: 1...60, step: 1.0)
                    .tint(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
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
            HStack(spacing: 12) {
                Image(systemName: audioRecorder.isListening ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                
                Text(audioRecorder.isListening ? "Stop Listening" : "Start Listening")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: audioRecorder.isListening ? 
                        [.red, .red.opacity(0.8)] : [.green, .green.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: (audioRecorder.isListening ? Color.red : Color.green).opacity(0.3), 
                   radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal)
        .scaleEffect(audioRecorder.isListening ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: audioRecorder.isListening)
    }
    
    @ViewBuilder
    private var statusMessages: some View {
        if !audioRecorder.statusMessage.isEmpty || !audioRecorder.errorMessage.isEmpty {
            VStack(spacing: 8) {
                if !audioRecorder.statusMessage.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text(audioRecorder.statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                if !audioRecorder.errorMessage.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(audioRecorder.errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var recordingsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                Text("Saved Recordings")
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
                VStack(spacing: 12) {
                    Image(systemName: "waveform.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Text("No recordings yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Start listening to create your first recording")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(audioRecorder.savedRecordings, id: \.lastPathComponent) { recording in
                        ModernRecordingRow(
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

struct RecordingRow: View {
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
                
                Button(action: onUpload) {
                    Image(systemName: "arrow.up.doc")
                        .foregroundColor(.orange)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Modern UI Components

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct ModernRecordingRow: View {
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
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        if let creationDate = try? recording.resourceValues(forKeys: [.creationDateKey]).creationDate {
            return formatter.string(from: creationDate)
        }
        return "Unknown"
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // File Icon
                ZStack {
                    Circle()
                        .fill(isPlaying ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: isTranscribed ? "doc.text.fill" : "waveform")
                        .foregroundColor(isTranscribed ? .green : .blue)
                        .font(.system(size: 16, weight: .medium))
                }
                
                // File Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(fileName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(dateString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status Badge
                if isTranscribing {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Processing")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
                } else if isTranscribed {
                    Text("Transcribed")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                }
            }
            
            // Action Buttons
            HStack(spacing: 16) {
                Button(action: isPlaying ? onStop : onPlay) {
                    HStack(spacing: 4) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        Text(isPlaying ? "Pause" : "Play")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isPlaying ? .red : .blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background((isPlaying ? Color.red : Color.blue).opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button(action: isTranscribed ? onViewTranscription : onTranscribe) {
                    HStack(spacing: 4) {
                        Image(systemName: isTranscribed ? "doc.text" : "icloud.and.arrow.up")
                        Text(isTranscribed ? "View" : "Transcribe")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                }
                .disabled(isTranscribing)
                
                Menu {
                    Button("Upload", action: onUpload)
                    Button("Share", action: onShare)
                    Divider()
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
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
