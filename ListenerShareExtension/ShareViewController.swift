import UIKit
import MobileCoreServices
import UniformTypeIdentifiers
import AVFoundation

class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Add to Listener"
        self.view.backgroundColor = UIColor.systemBackground
        
        // Add navigation buttons
        setupNavigationBar()
        
        // Add a simple UI
        setupUI()
        
        // Process the shared content immediately
        processSharedContent()
    }
    
    private func setupNavigationBar() {
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelAction))
        navigationItem.leftBarButtonItem = cancelButton
    }
    
    @objc private func cancelAction() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    private func setupUI() {
        let label = UILabel()
        label.text = "Saving audio file..."
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.tag = 100 // Tag for easy reference
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.startAnimating()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.tag = 101 // Tag for easy reference
        
        view.addSubview(label)
        view.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 20),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func updateStatusLabel(_ text: String) {
        DispatchQueue.main.async {
            if let label = self.view.viewWithTag(100) as? UILabel {
                label.text = text
            }
        }
    }
    
    private func processSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            finishWithError("No content found")
            return
        }
        
        // Try to handle as audio file
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.audio.identifier) {
            handleAudioFile(itemProvider: itemProvider)
        } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            handleFileURL(itemProvider: itemProvider)
        } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
            handleData(itemProvider: itemProvider)
        } else {
            finishWithError("File type not supported. Please share an audio file.")
        }
    }
    
    private func handleAudioFile(itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: UTType.audio.identifier, options: nil) { [weak self] (item, error) in
            DispatchQueue.main.async {
                if let error = error {
                    self?.finishWithError("Error loading audio: \(error.localizedDescription)")
                    return
                }
                if let url = item as? URL {
                    self?.saveAudioFile(url: url)
                } else if let data = item as? Data {
                    // Write the data to a temporary file so we can treat it like a URL
                    let tempDir = FileManager.default.temporaryDirectory
                    let tempURL = tempDir.appendingPathComponent("shared-\(UUID().uuidString).m4a")
                    do {
                        try data.write(to: tempURL)
                        self?.saveAudioFile(url: tempURL)
                    } catch {
                        self?.finishWithError("Could not save audio data: \(error.localizedDescription)")
                    }
                } else {
                    self?.finishWithError("Invalid audio item received")
                }
            }
        }
    }
    
    private func handleFileURL(itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] (item, error) in
            DispatchQueue.main.async {
                if let error = error {
                    self?.finishWithError("Error loading file: \(error.localizedDescription)")
                    return
                }
                
                guard let url = item as? URL else {
                    self?.finishWithError("Invalid file")
                    return
                }
                
                // Check if it's an audio file
                if self?.isAudioFile(url: url) == true {
                    self?.saveAudioFile(url: url)
                } else {
                    self?.finishWithError("File is not an audio file")
                }
            }
        }
    }
    
    private func handleData(itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: UTType.data.identifier, options: nil) { [weak self] (item, error) in
            DispatchQueue.main.async {
                if let error = error {
                    self?.finishWithError("Error loading data: \(error.localizedDescription)")
                    return
                }
                
                // For now, reject raw data - we need file URLs for audio
                self?.finishWithError("Please share the audio file directly, not as data")
            }
        }
    }
    
    private func isAudioFile(url: URL) -> Bool {
        let audioExtensions = ["mp3", "wav", "m4a", "aac", "ogg", "flac", "wma", "aiff", "au"]
        let pathExtension = url.pathExtension.lowercased()
        return audioExtensions.contains(pathExtension)
    }
    
    private func saveAudioFile(url: URL) {
        // Update UI to show we're processing
        updateStatusLabel("📁 Validating audio file...")
        
        // Validate audio file
        validateAudioFile(url: url) { [weak self] isValid in
            guard isValid else {
                self?.finishWithError("Invalid or corrupted audio file")
                return
            }
            
            // Process the audio file immediately
            self?.processAudioFileImmediately(url: url)
        }
    }
    
    private func processAudioFileImmediately(url: URL) {
        updateStatusLabel("📁 Saving...")
        
        Task {
            do {
                // Generate conversation name from filename (remove extension)
                let originalFilename = url.lastPathComponent
                let conversationName = originalFilename.replacingOccurrences(of: ".\(url.pathExtension)", with: "")
                
                // Save to shared container
                try await saveToSharedContainer(url: url, conversationName: conversationName)
                
                // Close immediately - main app will auto-process
                await MainActor.run {
                    self.finishWithSuccess(conversationName: conversationName)
                }
                
            } catch {
                await MainActor.run {
                    self.finishWithError("Failed to save: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func saveToSharedContainer(url: URL, conversationName: String) async throws {
        guard let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.mikeshaffer.listener") else {
            throw NSError(domain: "ShareExtension", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not access shared container"])
        }
        
        let pendingFolder = sharedURL.appendingPathComponent("PendingUploads")
        
        // Create folder if needed
        if !FileManager.default.fileExists(atPath: pendingFolder.path) {
            try FileManager.default.createDirectory(at: pendingFolder, withIntermediateDirectories: true)
        }
        
        // Copy the audio file
        let destinationURL = pendingFolder.appendingPathComponent(url.lastPathComponent)
        
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            try FileManager.default.copyItem(at: url, to: destinationURL)
        } else {
            try FileManager.default.copyItem(at: url, to: destinationURL)
        }
        
        // Create metadata
        let metadata = ShareMetadata(
            filename: url.lastPathComponent,
            originalFilename: url.lastPathComponent,
            notes: conversationName,
            timestamp: Int(Date().timeIntervalSince1970),
            fileExtension: url.pathExtension
        )
        
        // Save metadata
        let metadataURL = destinationURL.appendingPathExtension("metadata")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let metadataData = try encoder.encode(metadata)
        try metadataData.write(to: metadataURL)
    }
    
    private func validateAudioFile(url: URL, completion: @escaping (Bool) -> Void) {
        Task {
            let asset = AVURLAsset(url: url)
            do {
                let isPlayable = try await asset.load(.isPlayable)
                let duration = try await asset.load(.duration)
                let isValid = isPlayable && duration.seconds > 0
                
                DispatchQueue.main.async {
                    completion(isValid)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    private func finishWithSuccess(conversationName: String) {
        // Update the UI to show success
        updateStatusLabel("✅ '\(conversationName)' saved!")
        
        // Hide activity indicator
        if let activityIndicator = self.view.viewWithTag(101) as? UIActivityIndicatorView {
            activityIndicator.stopAnimating()
            activityIndicator.isHidden = true
        }
        
        // Complete after a brief delay to show the success message
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
    
    private func finishWithError(_ message: String) {
        // Update the UI to show error
        updateStatusLabel("❌ Error: \(message)")
        
        // Hide activity indicator
        if let activityIndicator = self.view.viewWithTag(101) as? UIActivityIndicatorView {
            activityIndicator.stopAnimating()
            activityIndicator.isHidden = true
        }
        
        // Complete after a brief delay to show the error message
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
    
}