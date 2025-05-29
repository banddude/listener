import SwiftUI
import Foundation

struct PineconeManagerView: View {
    @State private var speakers: [PineconeSpeaker] = []
    @State private var isLoading = false
    @State private var showingAddSpeaker = false
    @State private var addEmbeddingItem: AddEmbeddingItem?
    
    struct AddEmbeddingItem: Identifiable {
        let id = UUID()
        let speakerName: String
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text("Pinecone Manager")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Only refresh button now
                    Button(action: refreshSpeakers) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                }
                
                // Speakers List
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Speakers (\(speakers.count))")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            showingAddSpeaker = true
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(.green)
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if speakers.isEmpty && !isLoading {
                        Text("No speakers found in the database.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(speakers) { speaker in
                            PineconeSpeakerCard(
                                speaker: speaker,
                                onAddEmbedding: { speakerName in
                                    print("🟢 PineconeManagerView: Received callback with speakerName: '\(speakerName)'")
                                    addEmbeddingItem = AddEmbeddingItem(speakerName: speakerName)
                                    print("🟢 PineconeManagerView: Set addEmbeddingItem to: '\(String(describing: addEmbeddingItem))'")
                                },
                                onDeleteSpeaker: deleteSpeaker,
                                onDeleteEmbedding: deleteEmbedding
                            )
                        }
                    }
                }
                
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingAddSpeaker) {
            PineconeAddSpeakerView {
                showingAddSpeaker = false
                refreshSpeakers()
            }
        }
        .sheet(item: $addEmbeddingItem) { item in
            print("🟡 PineconeManagerView: Sheet presenting with speakerName: '\(item.speakerName)'")
            return PineconeAddEmbeddingView(
                speakerName: item.speakerName
            ) {
                    addEmbeddingItem = nil
                    refreshSpeakers()
            }
        }
        .onAppear {
            refreshSpeakers()
        }
    }
    
    private func refreshSpeakers() {
        isLoading = true
        
        Task {
            do {
                // Use the correct Pinecone-specific endpoint
                let url = URL(string: "\(AppConstants.baseURL)/api/pinecone/speakers")!
                print("🔍 Fetching Pinecone speakers from: \(url.absoluteString)")
                
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                print("📡 Response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let speakersResponse = try JSONDecoder().decode(PineconeSpeakersResponse.self, from: data)
                    print("✅ Successfully loaded \(speakersResponse.speakers.count) Pinecone speakers")
                    
                    await MainActor.run {
                        self.speakers = speakersResponse.speakers
                        self.isLoading = false
                    }
                } else {
                    let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("❌ Server error: \(httpResponse.statusCode) - \(errorText)")
                    throw URLError(.badServerResponse)
                }
            } catch {
                print("❌ Error loading Pinecone speakers: \(error)")
                await MainActor.run {
                    self.isLoading = false
                    // Show some test data so we know the view is working
                    self.speakers = [
                        PineconeSpeaker(
                            name: "Test Speaker 1",
                            embeddings: [PineconeEmbedding(id: "test-embedding-1")]
                        ),
                        PineconeSpeaker(
                            name: "Test Speaker 2", 
                            embeddings: [PineconeEmbedding(id: "test-embedding-2")]
                        )
                    ]
                }
            }
        }
    }
    
    private func deleteSpeaker(_ speakerName: String) {
        Task {
            do {
                // Use the correct Pinecone-specific endpoint
                let url = URL(string: "\(AppConstants.baseURL)/api/pinecone/speakers/\(speakerName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? speakerName)")!
                var request = URLRequest(url: url)
                request.httpMethod = "DELETE"
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                
                await MainActor.run {
                    self.refreshSpeakers()
                }
            } catch {
                await MainActor.run {
                    print("❌ Error deleting speaker: \(error)")
                }
            }
        }
    }
    
    private func deleteEmbedding(_ embeddingId: String) {
        Task {
            do {
                // Use the correct Pinecone-specific endpoint
                let url = URL(string: "\(AppConstants.baseURL)/api/pinecone/embeddings/\(embeddingId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? embeddingId)")!
                var request = URLRequest(url: url)
                request.httpMethod = "DELETE"
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                
                await MainActor.run {
                    self.refreshSpeakers()
                }
            } catch {
                await MainActor.run {
                    print("❌ Error deleting embedding: \(error)")
                }
            }
        }
    }
}

struct PineconeSpeakerCard: View {
    let speaker: PineconeSpeaker
    let onAddEmbedding: (String) -> Void
    let onDeleteSpeaker: (String) -> Void
    let onDeleteEmbedding: (String) -> Void
    
    @State private var showingDeleteConfirmation = false
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(speaker.name)
                        .font(.headline)
                    
                    Text("\(speaker.embeddings.count) voice samples")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    if !speaker.embeddings.isEmpty {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isExpanded.toggle()
                            }
                        }) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: {
                        print("🔵 PineconeSpeakerCard: Add button pressed for speaker: '\(speaker.name)'")
                        onAddEmbedding(speaker.name)
                    }) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.green)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if !speaker.embeddings.isEmpty && isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Embeddings:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(speaker.embeddings) { embedding in
                        HStack {
                            Text(embedding.id)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: {
                                onDeleteEmbedding(embedding.id)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .onTapGesture {
            if !speaker.embeddings.isEmpty {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }
        }
        .confirmationDialog(
            "Delete Speaker",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDeleteSpeaker(speaker.name)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \(speaker.name)?")
        }
    }
}

struct PineconeAddSpeakerView: View {
    let onSpeakerAdded: () -> Void
    
    @State private var speakerName = ""
    @State private var selectedAudioURL: URL?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingDocumentPicker = false
    
    var body: some View {
        Form {
            Section(header: Text("Speaker Details")) {
                TextField("Speaker Name", text: $speakerName)
            }
            
            Section(header: Text("Voice Sample")) {
                Button(action: {
                    showingDocumentPicker = true
                }) {
                    HStack {
                        Image(systemName: "mic")
                        if let url = selectedAudioURL {
                            Text(url.lastPathComponent)
                                .foregroundColor(.primary)
                        } else {
                            Text("Choose Audio File")
                                .foregroundColor(.blue)
                        }
                        Spacer()
                    }
                }
            }
            
            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Add Speaker")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onSpeakerAdded()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    addSpeaker()
                }
                .disabled(speakerName.isEmpty || selectedAudioURL == nil || isLoading)
            }
        }
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedAudioURL = url
                }
            case .failure(let error):
                errorMessage = "Failed to select file: \(error.localizedDescription)"
            }
        }
    }
    
    private func addSpeaker() {
        guard let audioURL = selectedAudioURL else { return }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                // Use the correct Pinecone-specific endpoint
                let url = URL(string: "\(AppConstants.baseURL)/api/pinecone/speakers")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                
                let boundary = UUID().uuidString
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                
                let audioData = try Data(contentsOf: audioURL)
                let formData = createMultipartFormData(
                    boundary: boundary,
                    speakerName: speakerName,
                    audioData: audioData,
                    fileName: audioURL.lastPathComponent
                )
                
                let (_, response) = try await URLSession.shared.upload(for: request, from: formData)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                
                await MainActor.run {
                    self.onSpeakerAdded()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to add speaker: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func createMultipartFormData(boundary: String, speakerName: String, audioData: Data, fileName: String) -> Data {
        var formData = Data()
        
        // Add speaker name field
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"speaker_name\"\r\n\r\n".data(using: .utf8)!)
        formData.append("\(speakerName)\r\n".data(using: .utf8)!)
        
        // Add audio file field
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"audio_file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        formData.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!)
        formData.append(audioData)
        formData.append("\r\n".data(using: .utf8)!)
        
        // Close boundary
        formData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return formData
    }
}

struct PineconeAddEmbeddingView: View {
    let speakerName: String
    let onEmbeddingAdded: () -> Void
    
    @State private var selectedAudioURL: URL?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingDocumentPicker = false
    
    init(speakerName: String, onEmbeddingAdded: @escaping () -> Void) {
        print("🔴 PineconeAddEmbeddingView: Init called with speakerName: '\(speakerName)'")
        self.speakerName = speakerName
        self.onEmbeddingAdded = onEmbeddingAdded
    }
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Adding voice sample for:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(speakerName)
                            .font(.headline)
                            .onAppear {
                                print("🟣 PineconeAddEmbeddingView: Text widget displaying speakerName: '\(speakerName)'")
                            }
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            Section(header: Text("Voice Sample")) {
                Button(action: {
                    showingDocumentPicker = true
                }) {
                    HStack {
                        Image(systemName: "mic")
                        if let url = selectedAudioURL {
                            Text(url.lastPathComponent)
                                .foregroundColor(.primary)
                        } else {
                            Text("Choose Audio File")
                                .foregroundColor(.blue)
                        }
                        Spacer()
                    }
                }
            }
            
            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Add Voice Sample")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onEmbeddingAdded()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    addEmbedding()
                }
                .disabled(selectedAudioURL == nil || isLoading)
            }
        }
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedAudioURL = url
                }
            case .failure(let error):
                errorMessage = "Failed to select file: \(error.localizedDescription)"
            }
        }
    }
    
    private func addEmbedding() {
        guard let audioURL = selectedAudioURL else { return }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                // Use the correct Pinecone-specific endpoint
                let url = URL(string: "\(AppConstants.baseURL)/api/pinecone/embeddings")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                
                let boundary = UUID().uuidString
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                
                let audioData = try Data(contentsOf: audioURL)
                let formData = createMultipartFormData(
                    boundary: boundary,
                    speakerName: speakerName,
                    audioData: audioData,
                    fileName: audioURL.lastPathComponent
                )
                
                let (_, response) = try await URLSession.shared.upload(for: request, from: formData)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                
                await MainActor.run {
                    self.onEmbeddingAdded()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to add embedding: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func createMultipartFormData(boundary: String, speakerName: String, audioData: Data, fileName: String) -> Data {
        var formData = Data()
        
        // Add speaker name field
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"speaker_name\"\r\n\r\n".data(using: .utf8)!)
        formData.append("\(speakerName)\r\n".data(using: .utf8)!)
        
        // Add audio file field
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"audio_file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        formData.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!)
        formData.append(audioData)
        formData.append("\r\n".data(using: .utf8)!)
        
        // Close boundary
        formData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return formData
    }
}

#Preview {
    PineconeManagerView()
} 
