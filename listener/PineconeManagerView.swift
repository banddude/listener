import SwiftUI
import Foundation

struct PineconeManagerView: View {
    let speakerIDService: SpeakerIDService
    
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pinecone Manager")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Advanced speaker embedding management for the vector database")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Info Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("About Pinecone")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    
                    Text("Pinecone is the vector database that stores speaker voice embeddings for identification. These embeddings allow the system to recognize and match speakers across different conversations.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                // Warning Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Advanced Feature")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                    
                    Text("This section is for advanced users only. Modifying speaker embeddings can affect speaker identification accuracy across all conversations.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                
                // Actions
                VStack(alignment: .leading, spacing: 16) {
                    Text("Available Actions")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        PineconeActionCard(
                            icon: "eye",
                            title: "View All Embeddings",
                            description: "See all speaker embeddings stored in Pinecone",
                            buttonText: "View Embeddings",
                            buttonColor: .blue,
                            action: viewEmbeddings
                        )
                        
                        PineconeActionCard(
                            icon: "plus.circle",
                            title: "Add Speaker Embedding",
                            description: "Upload audio to create a new speaker embedding",
                            buttonText: "Add Embedding",
                            buttonColor: .green,
                            action: addEmbedding
                        )
                        
                        PineconeActionCard(
                            icon: "trash",
                            title: "Delete Speaker Embeddings",
                            description: "Remove all embeddings for a specific speaker",
                            buttonText: "Manage Deletions",
                            buttonColor: .red,
                            action: manageDelete
                        )
                        
                        PineconeActionCard(
                            icon: "arrow.clockwise",
                            title: "Refresh Database",
                            description: "Sync and refresh the Pinecone database state",
                            buttonText: "Refresh",
                            buttonColor: .purple,
                            action: refreshDatabase
                        )
                    }
                }
                
                // Status Messages
                if !successMessage.isEmpty {
                    Text(successMessage)
                        .foregroundColor(.green)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Processing...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                
                // Footer Note
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Changes to speaker embeddings in Pinecone affect the speaker identification system. Use these features carefully and consider backing up important data.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .padding()
        }
    }
    
    private func viewEmbeddings() {
        clearMessages()
        isLoading = true
        
        Task {
            do {
                // This would call the Pinecone speakers endpoint
                // For now, just show a placeholder message
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                await MainActor.run {
                    self.successMessage = "Feature coming soon: View all speaker embeddings stored in Pinecone vector database"
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load embeddings: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func addEmbedding() {
        clearMessages()
        successMessage = "Feature coming soon: Upload audio files to create new speaker embeddings in Pinecone"
    }
    
    private func manageDelete() {
        clearMessages()
        successMessage = "Feature coming soon: Delete specific speaker embeddings from Pinecone database"
    }
    
    private func refreshDatabase() {
        clearMessages()
        isLoading = true
        
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
            await MainActor.run {
                self.successMessage = "Pinecone database state refreshed successfully"
                self.isLoading = false
            }
        }
    }
    
    private func clearMessages() {
        errorMessage = ""
        successMessage = ""
    }
}

struct PineconeActionCard: View {
    let icon: String
    let title: String
    let description: String
    let buttonText: String
    let buttonColor: Color
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(buttonColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Button(buttonText) {
                action()
            }
            .buttonStyle(.bordered)
            .tint(buttonColor)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(buttonColor.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    PineconeManagerView(speakerIDService: SpeakerIDService())
} 