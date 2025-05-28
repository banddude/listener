//
//  listenerApp.swift
//  listener
//
//  Created by Mike Shaffer on 5/23/25.
//

import SwiftUI

@main
struct listenerApp: App {
    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            MacContentView()
                .frame(minWidth: 1000, minHeight: 700)
            #else
            TabView {
                ContentView()
                    .tabItem {
                        Image(systemName: "mic")
                        Text("Record")
                    }
                
                DashboardView()
                    .tabItem {
                        Image(systemName: "list.bullet")
                        Text("Dashboard")
                    }
            }
            #endif
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif
    }
}

#if os(macOS)
struct MacContentView: View {
    @State private var selectedSidebarItem: SidebarItem = .record
    @StateObject private var audioRecorder = VoiceActivityRecorder()
    @StateObject private var speakerIDService = SpeakerIDService()
    
    enum SidebarItem: String, CaseIterable {
        case record = "Record"
        case conversations = "Conversations"
        case speakers = "Speakers"
        case upload = "Upload"
        case pinecone = "Pinecone"
        
        var icon: String {
            switch self {
            case .record: return "mic"
            case .conversations: return "bubble.left.and.bubble.right"
            case .speakers: return "person.2"
            case .upload: return "icloud.and.arrow.up"
            case .pinecone: return "magnifyingglass"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(SidebarItem.allCases, id: \.self, selection: $selectedSidebarItem) { item in
                NavigationLink(value: item) {
                    Label(item.rawValue, systemImage: item.icon)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250)
            .navigationTitle("Listener Pro")
        } detail: {
            // Main content area
            Group {
                switch selectedSidebarItem {
                case .record:
                    MacRecordView(audioRecorder: audioRecorder, speakerIDService: speakerIDService)
                case .conversations:
                    MacConversationsView(speakerIDService: speakerIDService)
                case .speakers:
                    MacSpeakersView(speakerIDService: speakerIDService)
                case .upload:
                    MacUploadView(speakerIDService: speakerIDService)
                case .pinecone:
                    MacPineconeView(speakerIDService: speakerIDService)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
}

struct MacRecordView: View {
    @ObservedObject var audioRecorder: VoiceActivityRecorder
    @ObservedObject var speakerIDService: SpeakerIDService
    @State private var selectedTranscriptionResult: TranscriptionResult?
    @State private var selectedRecording: URL?
    @State private var transcribedRecordings: Set<URL> = []
    @State private var currentlyTranscribing: URL?
    @State private var savedTranscriptions: [URL: TranscriptionResult] = [:]
    @State private var showingUploadSheet = false
    @State private var recordingToUpload: URL?
    
    var body: some View {
        HSplitView {
            // Left panel - Controls
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Voice Recording")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    // Status indicator
                    HStack {
                        Circle()
                            .fill(audioRecorder.isListening ? .green : .red)
                            .frame(width: 12, height: 12)
                        Text(audioRecorder.isListening ? "Listening" : "Stopped")
                            .font(.body)
                    }
                    
                    // Speech detection
                    if audioRecorder.isSpeechDetected {
                        HStack {
                            Image(systemName: "waveform")
                                .foregroundColor(.blue)
                            Text("Speech Detected")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Recording status
                    if audioRecorder.isRecordingClip {
                        VStack {
                            Text("Recording Clip")
                                .foregroundColor(.red)
                                .fontWeight(.medium)
                            Text("Duration: \(String(format: "%.1f", audioRecorder.currentClipDuration))s")
                                .font(.caption)
                        }
                    }
                }
                
                Divider()
                
                // Stats
                VStack(spacing: 12) {
                    Text("Statistics")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("Clips Saved:")
                            Spacer()
                            Text("\(audioRecorder.clipsCount)")
                                .fontWeight(.semibold)
                        }
                    }
                }
                
                Divider()
                
                // Controls
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("Silence Threshold")
                            .font(.headline)
                        
                        Stepper(value: $audioRecorder.silenceThreshold, in: 1...60, step: 1.0) {
                            Text("\(String(format: "%.0f", audioRecorder.silenceThreshold)) seconds")
                        }
                    }
                    
                    Button(audioRecorder.isListening ? "Stop Listening" : "Start Listening") {
                        if audioRecorder.isListening {
                            audioRecorder.stopListening()
                        } else {
                            audioRecorder.startListening()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(audioRecorder.isListening ? .red : .green)
                }
                
                // Status messages
                VStack(spacing: 8) {
                    if !audioRecorder.statusMessage.isEmpty {
                        Text(audioRecorder.statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    if !audioRecorder.errorMessage.isEmpty {
                        Text(audioRecorder.errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                
                Spacer()
            }
            .padding()
            .frame(width: 300)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Right panel - Recordings
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("Recordings")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                    Button("Refresh") {
                        audioRecorder.refreshRecordings()
                    }
                }
                .padding()
                
                Divider()
                
                // Recordings list
                if audioRecorder.savedRecordings.isEmpty {
                    VStack {
                        Spacer()
                        Text("No recordings yet")
                            .foregroundColor(.secondary)
                            .font(.title3)
                        Text("Start listening to create your first recording")
                            .foregroundColor(.secondary)
                            .font(.body)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List {
                        ForEach(audioRecorder.savedRecordings, id: \.lastPathComponent) { recording in
                            MacRecordingRow(
                                recording: recording,
                                isPlaying: audioRecorder.currentlyPlayingURL == recording,
                                isTranscribing: currentlyTranscribing == recording,
                                isTranscribed: transcribedRecordings.contains(recording),
                                onPlay: { audioRecorder.playRecording(recording) },
                                onStop: { audioRecorder.stopPlayback() },
                                onTranscribe: { transcribeRecording(recording) },
                                onViewTranscription: { viewTranscription(recording) },
                                onShare: { shareRecording(recording) },
                                onUpload: { uploadRecording(recording) }
                            )
                        }
                        .onDelete(perform: deleteRecordings)
                    }
                }
            }
        }
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
                .frame(width: 800, height: 600)
            }
        }
        .sheet(isPresented: $showingUploadSheet) {
            if let recording = recordingToUpload {
                UploadView(
                    speakerIDService: speakerIDService,
                    preselectedFile: recording
                )
                .frame(width: 600, height: 400)
            }
        }
    }
    
    // Helper functions (same as ContentView)
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
                let response = try await speakerIDService.uploadConversation(
                    audioFileURL: recording,
                    displayName: recording.lastPathComponent.replacingOccurrences(of: ".wav", with: "")
                )
                
                do {
                    let conversationDetail = try await waitForProcessingCompletion(
                        conversationId: response.conversation_id
                    )
                    
                    let result = convertToTranscriptionResult(conversationDetail)
                    
                    await MainActor.run {
                        self.savedTranscriptions[recording] = result
                        self.transcribedRecordings.insert(recording)
                        self.currentlyTranscribing = nil
                    }
                    return
                } catch {
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
                }
            }
        }
    }
    
    private func viewTranscription(_ recording: URL) {
        selectedRecording = recording
        selectedTranscriptionResult = savedTranscriptions[recording]
    }
    
    private func loadSavedTranscriptions() {
        for recording in audioRecorder.savedRecordings {
            let transcriptionURL = transcriptionFileURL(for: recording)
            
            if FileManager.default.fileExists(atPath: transcriptionURL.path) {
                do {
                    let data = try Data(contentsOf: transcriptionURL)
                    let result = try JSONDecoder().decode(TranscriptionResult.self, from: data)
                    savedTranscriptions[recording] = result
                    transcribedRecordings.insert(recording)
                } catch {
                    print("Failed to load transcription: \(error)")
                }
            }
        }
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
        showingUploadSheet = true
    }
    
    private func waitForProcessingCompletion(conversationId: String) async throws -> ConversationDetail {
        let maxAttempts = 30
        var attempts = 0
        
        while attempts < maxAttempts {
            attempts += 1
            
            do {
                let details = try await speakerIDService.getConversationDetails(conversationId: conversationId)
                
                if !details.utterances.isEmpty {
                    return details
                }
            } catch {
                print("Error checking processing status: \(error)")
            }
            
            try await Task.sleep(nanoseconds: 10_000_000_000)
        }
        
        throw SpeakerIDError.uploadFailed
    }
    
    private func convertToTranscriptionResult(_ conversationDetail: ConversationDetail) -> TranscriptionResult {
        let segments = conversationDetail.utterances.map { utterance in
            ConversationSegment(
                timestamp: utterance.start_time,
                speaker: utterance.speaker_name,
                text: utterance.text
            )
        }
        
        let speakers = Array(Set(conversationDetail.utterances.map { $0.speaker_name }))
        
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

struct MacRecordingRow: View {
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
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        if let creationDate = try? recording.resourceValues(forKeys: [.creationDateKey]).creationDate {
            return formatter.string(from: creationDate)
        }
        return "Unknown"
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(fileName)
                    .font(.body)
                    .fontWeight(.medium)
                Text(dateString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: isPlaying ? onStop : onPlay) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .foregroundColor(isPlaying ? .red : .blue)
                }
                .buttonStyle(.plain)
                .help(isPlaying ? "Stop" : "Play")
                
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
                .buttonStyle(.plain)
                .disabled(isTranscribing)
                .help(isTranscribed ? "View transcription" : "Transcribe")
                
                Button(action: onUpload) {
                    Image(systemName: "arrow.up.doc")
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                .help("Upload to server")
                
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .help("Share")
            }
        }
        .padding(.vertical, 8)
    }
}

// Mac-optimized dashboard views
struct MacConversationsView: View {
    @ObservedObject var speakerIDService: SpeakerIDService
    @State private var conversations: [BackendConversationSummary] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Conversations")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Refresh") {
                    loadConversations()
                }
            }
            .padding()
            
            Divider()
            
            // Content
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Text("Loading conversations...")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ConversationsListView(conversations: conversations, speakerIDService: speakerIDService)
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .onAppear {
            loadConversations()
        }
    }
    
    private func loadConversations() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let loadedConversations = try await speakerIDService.getAllConversations()
                await MainActor.run {
                    self.conversations = loadedConversations
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load conversations: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

struct MacSpeakersView: View {
    @ObservedObject var speakerIDService: SpeakerIDService
    @State private var speakers: [Speaker] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Speakers")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Refresh") {
                    loadSpeakers()
                }
            }
            .padding()
            
            Divider()
            
            // Content
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Text("Loading speakers...")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                SpeakersListView(speakers: speakers, speakerIDService: speakerIDService)
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .onAppear {
            loadSpeakers()
        }
    }
    
    private func loadSpeakers() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let loadedSpeakers = try await speakerIDService.getSpeakers()
                await MainActor.run {
                    self.speakers = loadedSpeakers
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load speakers: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

struct MacUploadView: View {
    @ObservedObject var speakerIDService: SpeakerIDService
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Upload Audio")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            
            Divider()
            
            // Content
            UploadView(speakerIDService: speakerIDService)
                .padding()
        }
    }
}

struct MacPineconeView: View {
    @ObservedObject var speakerIDService: SpeakerIDService
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Pinecone Management")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            
            Divider()
            
            // Content
            PineconeManagerView(speakerIDService: speakerIDService)
                .padding()
        }
    }
}
#endif
