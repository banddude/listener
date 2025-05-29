import Foundation
import Combine

class SharedAudioManager: ObservableObject {
    static let shared = SharedAudioManager()
    
    private let groupIdentifier = "group.com.mikeshaffer.listener"
    private let folderName = "PendingUploads"
    
    @Published var pendingUploads: [SharedAudioFile] = []
    
    private init() {
        loadPendingUploads()
    }
    
    var sharedContainerURL: URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)
    }
    
    var pendingUploadsURL: URL? {
        return sharedContainerURL?.appendingPathComponent(folderName)
    }
    
    func loadPendingUploads() {
        guard let pendingFolder = pendingUploadsURL else {
            print("Error: Could not access shared container")
            return
        }
        
        // Create the pending uploads folder if it doesn't exist
        if !FileManager.default.fileExists(atPath: pendingFolder.path) {
            do {
                try FileManager.default.createDirectory(at: pendingFolder, withIntermediateDirectories: true, attributes: nil)
                print("Created PendingUploads folder at: \(pendingFolder.path)")
            } catch {
                print("Error creating PendingUploads folder: \(error)")
                return
            }
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: pendingFolder, 
                                                                      includingPropertiesForKeys: [.creationDateKey], 
                                                                      options: [.skipsHiddenFiles])
            
            let audioFiles = contents.filter { $0.pathExtension != "metadata" }
            var sharedFiles: [SharedAudioFile] = []
            var newFilesDetected = false
            
            for audioURL in audioFiles {
                let metadataURL = pendingFolder.appendingPathComponent("\(audioURL.lastPathComponent).metadata")
                
                if FileManager.default.fileExists(atPath: metadataURL.path) {
                    do {
                        let metadataData = try Data(contentsOf: metadataURL)
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .secondsSince1970
                        let metadata = try decoder.decode(ShareMetadata.self, from: metadataData)
                        
                        let sharedFile = SharedAudioFile(
                            id: UUID(),
                            audioURL: audioURL,
                            metadata: metadata,
                            uploadStatus: .pending
                        )
                        sharedFiles.append(sharedFile)
                        
                        // Check if this is a new file (not in current list)
                        if !pendingUploads.contains(where: { $0.audioURL.lastPathComponent == audioURL.lastPathComponent }) {
                            newFilesDetected = true
                        }
                    } catch {
                        print("Error loading metadata for \(audioURL.lastPathComponent): \(error)")
                    }
                } else {
                    // Create minimal metadata for files without metadata
                    let metadata = ShareMetadata(
                        filename: audioURL.lastPathComponent,
                        originalFilename: audioURL.lastPathComponent,
                        notes: "",
                        timestamp: Int(Date().timeIntervalSince1970),
                        fileExtension: audioURL.pathExtension
                    )
                    
                    let sharedFile = SharedAudioFile(
                        id: UUID(),
                        audioURL: audioURL,
                        metadata: metadata,
                        uploadStatus: .pending
                    )
                    sharedFiles.append(sharedFile)
                    
                    // This is definitely a new file
                    if !pendingUploads.contains(where: { $0.audioURL.lastPathComponent == audioURL.lastPathComponent }) {
                        newFilesDetected = true
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.pendingUploads = sharedFiles.sorted { $0.metadata.timestamp > $1.metadata.timestamp }
                
                // Auto-process new files immediately
                if newFilesDetected {
                    print("🚀 New shared files detected - starting auto-processing")
                    Task {
                        await self.processAllPendingUploads()
                    }
                }
            }
            
        } catch {
            print("Error loading pending uploads: \(error)")
        }
    }
    
    func processNextPendingUpload() async {
        guard let nextUpload = pendingUploads.first(where: { $0.uploadStatus == .pending }) else {
            return
        }
        
        await updateUploadStatus(for: nextUpload.id, status: .uploading)
        
        do {
            _ = try await uploadAudioFile(nextUpload)
            await updateUploadStatus(for: nextUpload.id, status: .completed)
            await cleanupProcessedFile(nextUpload)
        } catch {
            print("Error uploading \(nextUpload.metadata.originalFilename): \(error)")
            await updateUploadStatus(for: nextUpload.id, status: .failed)
        }
    }
    
    func processAllPendingUploads() async {
        let pendingFiles = pendingUploads.filter { $0.uploadStatus == .pending }
        
        for _ in pendingFiles {
            await processNextPendingUpload()
        }
    }
    
    @MainActor
    private func uploadAudioFile(_ sharedFile: SharedAudioFile) async throws -> ConversationResponse {
        let audioData = try Data(contentsOf: sharedFile.audioURL)
        
        // Upload using the existing SpeakerIDService
        let speakerIDService = SpeakerIDService()
        return try await speakerIDService.uploadConversation(
            audioData: audioData,
            filename: sharedFile.metadata.originalFilename,
            notes: sharedFile.metadata.notes.isEmpty ? nil : sharedFile.metadata.notes
        )
    }
    
    private func updateUploadStatus(for id: UUID, status: UploadStatus) async {
        await MainActor.run {
            if let index = pendingUploads.firstIndex(where: { $0.id == id }) {
                pendingUploads[index].uploadStatus = status
            }
        }
    }
    
    private func cleanupProcessedFile(_ sharedFile: SharedAudioFile) async {
        do {
            // Remove the audio file
            try FileManager.default.removeItem(at: sharedFile.audioURL)
            
            // Remove the metadata file
            let metadataURL = sharedFile.audioURL.appendingPathExtension("metadata")
            if FileManager.default.fileExists(atPath: metadataURL.path) {
                try FileManager.default.removeItem(at: metadataURL)
            }
            
            // Remove from the pending uploads list
            await MainActor.run {
                pendingUploads.removeAll { $0.id == sharedFile.id }
            }
        } catch {
            print("Error cleaning up processed file: \(error)")
        }
    }
    
    func deleteSharedFile(_ sharedFile: SharedAudioFile) {
        Task {
            await cleanupProcessedFile(sharedFile)
        }
    }
}

struct SharedAudioFile: Identifiable {
    let id: UUID
    let audioURL: URL
    let metadata: ShareMetadata
    var uploadStatus: UploadStatus
}

enum UploadStatus {
    case pending
    case uploading
    case completed
    case failed
}

struct ShareMetadata: Codable {
    let filename: String
    let originalFilename: String
    let notes: String
    let timestamp: Int
    let fileExtension: String
}