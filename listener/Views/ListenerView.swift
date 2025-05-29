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
    @State private var currentlyUploading: URL?
    @State private var uploadedRecordings: [URL: String] = [:] // URL to conversation_id mapping
    @State private var conversations: [BackendConversationSummary] = []
    
    @EnvironmentObject var navigationManager: AppNavigationManager

    var body: some View {
        AppScrollContainer {
            // Header
            headerSection
            
            // Recording Controls Card
            recordingControlsCard
            
            // Stats Card
            statsCard
            
            // Recordings List
            recordingsSection
        }
        .onAppear {
            audioRecorder.requestPermissions()
            audioRecorder.refreshRecordings()
            loadConversations()
        }
        .onChange(of: audioRecorder.savedRecordings) {
            // No need to load transcriptions anymore
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Voice Recorder")
                    .appTitle()
                
                Text("Record and process conversations")
                    .appSubtitle()
            }
            
            Spacer()
        }
    }
    
    private var recordingControlsCard: some View {
        VStack(spacing: 16) {
            // Status indicator
            HStack {
                AppStatusIndicator(
                    isActive: audioRecorder.isListening,
                    activeText: "Listening",
                    inactiveText: "Ready to Record",
                    detailText: audioRecorder.isSpeechDetected ? "Speech Detected" : 
                               audioRecorder.isRecordingClip ? "Recording - \(String(format: "%.1f", audioRecorder.currentClipDuration))s" : 
                               audioRecorder.isListening ? "Waiting for speech..." : "Tap Start to begin"
                )
                
                Spacer()
                
                // Silence threshold control
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Silence: \(Int(audioRecorder.silenceThreshold))s")
                        .appCaption()
                    
                    HStack(spacing: 8) {
                        Text("1s")
                            .font(.caption2)
                            .foregroundColor(.secondaryText)
                        
                        Slider(value: $audioRecorder.silenceThreshold, in: 1...60, step: 1.0)
                            .frame(width: 80)
                        
                        Text("60s")
                            .font(.caption2)
                            .foregroundColor(.secondaryText)
                    }
                }
            }
            
            // Main control button
            Button(action: {
                if audioRecorder.isListening {
                    audioRecorder.stopListening()
                } else {
                    audioRecorder.startListening()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: audioRecorder.isListening ? "stop.circle.fill" : AppIcons.record)
                        .font(.title2)
                    
                    Text(audioRecorder.isListening ? "Stop Recording" : "Start Recording")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(audioRecorder.isListening ? Color.recordingInactive : Color.recordingActive)
                .cornerRadius(12)
            }
            
            // Status messages
            if !audioRecorder.statusMessage.isEmpty {
                Text(audioRecorder.statusMessage)
                    .appCaption()
                    .foregroundColor(.speechDetected)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentLight)
                    .cornerRadius(12)
            }
            
            if !audioRecorder.errorMessage.isEmpty {
                Text(audioRecorder.errorMessage)
                    .appCaption()
                    .foregroundColor(.destructive)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.destructiveLight)
                    .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color.materialHeavy, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var statsCard: some View {
        HStack(spacing: 0) {
            ListenerStatItem(
                icon: AppIcons.recording,
                title: "Recordings",
                value: "\(audioRecorder.clipsCount)"
            )
            .frame(maxWidth: .infinity)
            
            ListenerStatItem(
                icon: AppIcons.upload,
                title: "Uploaded",
                value: "\(uploadedRecordings.count)"
            )
            .frame(maxWidth: .infinity)
            
            ListenerStatItem(
                icon: AppIcons.checkmark,
                title: "Processed",
                value: "\(conversations.count)"
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(Color.materialMedium, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var recordingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(
                title: "Recordings",
                actionIcon: AppIcons.refresh
            ) {
                    audioRecorder.refreshRecordings()
                    loadConversations()
            }
            
            if audioRecorder.savedRecordings.isEmpty {
                AppEmptyState(
                    icon: AppIcons.noRecordings,
                    title: "No recordings yet",
                    subtitle: "Tap 'Start Recording' to begin capturing conversations"
                )
            } else {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(audioRecorder.savedRecordings, id: \.lastPathComponent) { recording in
                        RecordingRow(
                            recording: recording,
                            isPlaying: audioRecorder.currentlyPlayingURL == recording,
                            isUploading: currentlyUploading == recording,
                            isUploaded: uploadedRecordings.keys.contains(recording),
                            onPlay: { audioRecorder.playRecording(recording) },
                            onStop: { audioRecorder.stopPlayback() },
                            onUpload: { uploadRecording(recording) },
                            onViewConversation: { viewConversation(recording) },
                            onShare: { shareRecording(recording) },
                            onDelete: { deleteRecording(recording) }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Functions
    
    private func uploadRecording(_ recording: URL) {
        guard !uploadedRecordings.keys.contains(recording) else { return }
        
        currentlyUploading = recording
        
        Task {
            do {
                let response = try await speakerIDService.uploadConversation(
                    audioFileURL: recording,
                    displayName: recording.lastPathComponent.replacingOccurrences(of: ".wav", with: "")
                )
                
                await MainActor.run {
                    self.uploadedRecordings[recording] = response.conversation_id
                    self.currentlyUploading = nil
                    print("✅ Successfully uploaded recording: \(response.conversation_id)")
                    
                    // Refresh conversations list to show the new one
                    loadConversations()
                }
            } catch {
                await MainActor.run {
                    self.currentlyUploading = nil
                    print("❌ Failed to upload recording: \(error.localizedDescription)")
                    // You could show an error alert here if desired
                }
            }
        }
    }
    
    private func viewConversation(_ recording: URL) {
        guard let conversationId = uploadedRecordings[recording] else { return }
        
        navigationManager.navigateToConversation(id: conversationId)
    }
    
    private func shareRecording(_ recording: URL) {
        audioRecorder.shareRecording(recording)
    }
    
    private func deleteRecording(_ recording: URL) {
        // Remove from uploaded recordings if it was uploaded
        uploadedRecordings.removeValue(forKey: recording)
        
        // Delete the actual file
        audioRecorder.deleteRecording(recording)
    }
    
    private func loadConversations() {
        Task {
            do {
                let fetchedConversations = try await speakerIDService.getAllConversations()
                await MainActor.run {
                    self.conversations = fetchedConversations
                }
            } catch {
                print("⚠️ Failed to load conversations: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Recording Row Component

struct RecordingRow: View {
    let recording: URL
    let isPlaying: Bool
    let isUploading: Bool
    let isUploaded: Bool
    let onPlay: () -> Void
    let onStop: () -> Void
    let onUpload: () -> Void
    let onViewConversation: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void
    
    private var fileName: String {
        recording.lastPathComponent.replacingOccurrences(of: ".wav", with: "")
    }
    
    private var timeString: String {
        if let creationDate = try? recording.resourceValues(forKeys: [.creationDateKey]).creationDate {
            return DateUtilities.formatTimestamp(creationDate)
        }
        return ""
    }
    
    private var fileSizeString: String {
        if let size = try? recording.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            return DurationUtilities.formatFileSize(Int64(size))
        }
        return ""
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Status indicator
            Circle()
                .fill(isUploaded ? Color.success : (isUploading ? Color.accent : Color.lightGrayBackground))
                .frame(width: 36, height: 36)
                .overlay(
                    Group {
                        if isUploading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: isUploaded ? "checkmark" : "waveform")
                                .font(.subheadline)
                                .foregroundColor(isUploaded ? .white : .secondaryText)
                        }
                    }
                )
            
            VStack(alignment: .leading, spacing: 8) {
                // File info
                VStack(alignment: .leading, spacing: 4) {
                    Text(fileName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    HStack(spacing: 12) {
                        if !timeString.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text(timeString)
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        if !fileSizeString.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "doc")
                                    .font(.caption2)
                                Text(fileSizeString)
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Action buttons
                HStack(spacing: 8) {
                    // Play/Pause button
                    Button(action: isPlaying ? onStop : onPlay) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.accent)
                            .cornerRadius(8)
                    }
                    
                    // Upload/View Conversation button
                    if isUploaded {
                        Button(action: onViewConversation) {
                            Image(systemName: "doc.text")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.accent)
                                .cornerRadius(8)
                        }
                    } else {
                        Button(action: onUpload) {
                            Image(systemName: isUploading ? "arrow.clockwise" : "icloud.and.arrow.up")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(isUploading ? Color.mediumGrayBackground : Color.accent)
                                .cornerRadius(8)
                                .rotationEffect(.degrees(isUploading ? 360 : 0))
                                .animation(isUploading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isUploading)
                        }
                        .disabled(isUploading)
                    }
                    
                    // Share button
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.accent)
                            .cornerRadius(8)
                    }
                    
                    // Delete button
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.destructive)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color.materialMedium, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isUploaded ? Color.success.opacity(0.3) : Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Stat Item Component

struct ListenerStatItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accent)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ListenerView()
}
