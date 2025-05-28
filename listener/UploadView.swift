import SwiftUI
import UniformTypeIdentifiers
import Foundation

struct UploadView: View {
    let speakerIDService: SpeakerIDService
    let preselectedFile: URL?
    
    @State private var selectedFileURL: URL?
    @State private var displayName = ""
    @State private var matchThreshold = 0.40
    @State private var autoUpdateThreshold = 0.50
    @State private var isUploading = false
    @State private var uploadProgress = 0.0
    @State private var uploadMessage = ""
    @State private var showingFilePicker = false
    @State private var uploadResult: ConversationResponse?
    @State private var errorMessage = ""
    
    init(speakerIDService: SpeakerIDService, preselectedFile: URL? = nil) {
        self.speakerIDService = speakerIDService
        self.preselectedFile = preselectedFile
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Upload Audio File")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Upload an audio conversation for speaker identification and transcription")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // File Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Audio File")
                        .font(.headline)
                    
                    if let fileURL = selectedFileURL {
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(fileURL.lastPathComponent)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if let fileSize = getFileSize(fileURL) {
                                    Text(fileSize)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Button("Change") {
                                showingFilePicker = true
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        Button(action: {
                            showingFilePicker = true
                        }) {
                            VStack(spacing: 12) {
                                Image(systemName: "icloud.and.arrow.up")
                                    .font(.system(size: 32))
                                    .foregroundColor(.blue)
                                
                                Text("Select Audio File")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                Text("Supported formats: MP3, WAV, M4A, FLAC")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [5]))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // Display Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Name (Optional)")
                        .font(.headline)
                    
                    TextField("Enter a name for this conversation", text: $displayName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Advanced Settings
                VStack(alignment: .leading, spacing: 16) {
                    Text("Advanced Settings")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Match Threshold")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(matchThreshold, specifier: "%.2f")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $matchThreshold, in: 0.1...0.9, step: 0.05)
                                .accentColor(.blue)
                            
                            Text("Lower values are more sensitive to speaker matching")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Auto-Update Threshold")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(autoUpdateThreshold, specifier: "%.2f")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $autoUpdateThreshold, in: 0.1...0.9, step: 0.05)
                                .accentColor(.blue)
                            
                            Text("Threshold for automatically updating speaker embeddings")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Upload Button
                Button(action: uploadFile) {
                    HStack {
                        if isUploading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "icloud.and.arrow.up")
                        }
                        
                        Text(isUploading ? "Uploading..." : "Upload & Process")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedFileURL != nil && !isUploading ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(selectedFileURL == nil || isUploading)
                
                // Progress
                if isUploading && uploadProgress > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Upload Progress")
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(uploadProgress * 100))%")
                                .font(.caption)
                        }
                        
                        ProgressView(value: uploadProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    }
                }
                
                // Upload Message
                if !uploadMessage.isEmpty {
                    Text(uploadMessage)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Error Message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Success Result
                if let result = uploadResult {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Upload Successful!")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        
                        Text("Conversation ID: \(result.conversation_id)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(result.message)
                            .font(.subheadline)
                        
                        Button("View Conversations") {
                            // This would navigate back to conversations tab
                            resetForm()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [
                .audio,
                UTType(filenameExtension: "mp3")!,
                UTType(filenameExtension: "wav")!,
                UTType(filenameExtension: "m4a")!,
                UTType(filenameExtension: "flac")!
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedFileURL = url
                    if displayName.isEmpty {
                        displayName = url.deletingPathExtension().lastPathComponent
                    }
                }
            case .failure(let error):
                errorMessage = "Failed to select file: \(error.localizedDescription)"
            }
        }
        .onAppear {
            if let preselectedFile = preselectedFile {
                selectedFileURL = preselectedFile
                displayName = preselectedFile.deletingPathExtension().lastPathComponent
            }
        }
    }
    
    private func getFileSize(_ url: URL) -> String? {
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = resources.fileSize {
                let formatter = ByteCountFormatter()
                formatter.countStyle = .file
                return formatter.string(fromByteCount: Int64(fileSize))
            }
        } catch {
            print("Failed to get file size: \(error)")
        }
        return nil
    }
    
    private func uploadFile() {
        guard let fileURL = selectedFileURL else { return }
        
        isUploading = true
        uploadProgress = 0.0
        uploadMessage = "Preparing upload..."
        errorMessage = ""
        uploadResult = nil
        
        Task {
            do {
                let result = try await speakerIDService.uploadConversation(
                    audioFileURL: fileURL,
                    displayName: displayName.isEmpty ? nil : displayName,
                    matchThreshold: matchThreshold,
                    autoUpdateThreshold: autoUpdateThreshold
                )
                
                await MainActor.run {
                    self.uploadResult = result
                    self.isUploading = false
                    self.uploadMessage = "Processing complete! The conversation has been uploaded and processed."
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Upload failed: \(error.localizedDescription)"
                    self.isUploading = false
                    self.uploadMessage = ""
                }
            }
        }
    }
    
    private func resetForm() {
        selectedFileURL = nil
        displayName = ""
        uploadProgress = 0.0
        uploadMessage = ""
        errorMessage = ""
        uploadResult = nil
        isUploading = false
    }
}

#Preview {
    UploadView(speakerIDService: SpeakerIDService())
} 