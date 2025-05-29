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
    @State private var selectedRecording: URL?
    @State private var currentlyUploading: Set<URL> = []
    
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
            // No longer need to load transcriptions
        }
        .sheet(item: $selectedRecording) { recording in
            if let recording = selectedRecording {
                TranscriptionDetailView(
                    recording: recording,
                    transcriptionResult: nil
                )
            } else {
                Text("Error: Recording not found")
                    .padding()
            }
        }
    }
    
    // MARK: - Main Content
    
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
            
            Text(audioRecorder.isListening ? "Listening" : "Not Listening")
                .font(.headline)
            
            Spacer()
            
            Text("Threshold: \(Int(audioRecorder.noiseThreshold * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
    
    private var quickStats: some View {
        HStack(spacing: 16) {
            StatItem(label: "Recordings", value: "\(audioRecorder.savedRecordings.count)")
            
            VStack(spacing: 4) {
                Text("Threshold")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(value: $audioRecorder.noiseThreshold, in: 0.1...0.9, step: 0.1)
                    .frame(width: 80)
            }
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
                Image(systemName: audioRecorder.isListening ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.title2)
                Text(audioRecorder.isListening ? "Stop" : "Start")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(audioRecorder.isListening ? .red : .blue)
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    private var recordingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recordings")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            if audioRecorder.savedRecordings.isEmpty {
                Text("No recordings yet")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(audioRecorder.savedRecordings, id: \.self) { recording in
                    CompactRecordingRow(
                        recording: recording,
                        isPlaying: audioRecorder.currentlyPlayingURL == recording,
                        isTranscribing: false,
                        isTranscribed: false,
                        isUploading: currentlyUploading.contains(recording),
                        onPlay: { audioRecorder.playRecording(recording) },
                        onStop: { audioRecorder.stopPlayback() },
                        onTranscribe: {},
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
        }
    }
    
    // MARK: - Helper Functions
    
    private func viewTranscription(_ recording: URL) {
        selectedRecording = recording
    }
    
    private func shareRecording(_ recording: URL) {
        let activityVC = UIActivityViewController(activityItems: [recording], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func uploadRecording(_ recording: URL) {
        currentlyUploading.insert(recording)
        
        Task {
            do {
                // Extract filename for display name
                let displayName = recording.lastPathComponent.replacingOccurrences(of: ".wav", with: "")
                
                // Upload directly to speaker ID service
                let response = try await speakerIDService.uploadConversation(
                    audioFileURL: recording,
                    displayName: displayName
                )
                
                await MainActor.run {
                    currentlyUploading.remove(recording)
                    print("✅ Successfully uploaded recording: \(displayName)")
                    print("📄 Conversation ID: \(response.conversation_id)")
                }
            } catch {
                await MainActor.run {
                    currentlyUploading.remove(recording)
                    print("❌ Failed to upload recording: \(error)")
                }
            }
        }
    }
    
    private func deleteRecordings(at offsets: IndexSet) {
        for index in offsets {
            let recording = audioRecorder.savedRecordings[index]
            
            // Delete the file
            try? FileManager.default.removeItem(at: recording)
        }
        
        audioRecorder.refreshRecordings()
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CompactRecordingRow: View {
    let recording: URL
    let isPlaying: Bool
    let isTranscribing: Bool
    let isTranscribed: Bool
    let isUploading: Bool
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
    
    var body: some View {
        HStack(spacing: 12) {
            // Play/Stop Button
            Button(action: isPlaying ? onStop : onPlay) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(isPlaying ? .red : .blue)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(fileName)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                
                Text(formatDate(recording))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                // Upload Button
                Button(action: onUpload) {
                    Image(systemName: isUploading ? "clock" : "icloud.and.arrow.up")
                        .foregroundColor(isUploading ? .orange : .blue)
                }
                .disabled(isUploading)
                
                // Share Button
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                }
                
                // Delete Button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            .font(.system(size: 16))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
    
    private func formatDate(_ url: URL) -> String {
        let fileName = url.lastPathComponent
        let dateStr = String(fileName.dropFirst(10).dropLast(4)) // Remove "Recording_" and ".wav"
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        
        if let date = formatter.date(from: dateStr) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        
        return dateStr
    }
}

#Preview {
    ListenerView()
} 