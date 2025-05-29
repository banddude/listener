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
            VStack(alignment: .leading, spacing: AppSpacing.mediumLarge) {
                // Header
                Text("Upload")
                    .appTitle()
                    .padding(.horizontal, AppSpacing.medium)
                
                // File Selection Card
                VStack(alignment: .leading, spacing: AppSpacing.mediumSmall) {
                    if let fileURL = selectedFileURL {
                        HStack(spacing: AppSpacing.mediumSmall) {
                            Image(systemName: AppIcons.document)
                                .foregroundColor(.accent)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: AppSpacing.minimal) {
                                Text(fileURL.lastPathComponent)
                                    .appHeadline()
                                
                                if let fileSize = getFileSize(fileURL) {
                                    Text(fileSize)
                                        .appCaption()
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                showingFilePicker = true
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.accent)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    } else {
                        Button(action: {
                            showingFilePicker = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "icloud.and.arrow.up")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                
                                Text("Select Audio File")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 1, dash: [5]))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                
                // Display Name Card
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Conversation name (optional)", text: $displayName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Settings Card
                VStack(alignment: .leading, spacing: 16) {
                    Text("Settings")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
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
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
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
                        
                        Text(isUploading ? "Processing..." : "Upload & Process")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedFileURL != nil && !isUploading ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(selectedFileURL == nil || isUploading)
                .padding(.horizontal)
                
                // Progress
                if isUploading && uploadProgress > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Progress")
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(uploadProgress * 100))%")
                                .font(.caption)
                        }
                        
                        ProgressView(value: uploadProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Status Messages
                if !uploadMessage.isEmpty {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text(uploadMessage)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                if !errorMessage.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Success Result
                if let result = uploadResult {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            Text("Upload Complete!")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        
                        Text(result.message)
                            .font(.subheadline)
                        
                        Button("View Conversations") {
                            resetForm()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
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
