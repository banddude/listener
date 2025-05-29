import SwiftUI
import Foundation

struct AddSpeakerView: View {
    let speakerIDService: SpeakerIDService
    let onSpeakerAdded: () -> Void
    
    @State private var speakerName = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Add New Speaker")
                    .appTitle()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Speaker Name")
                        .appHeadline()
                    
                    TextField("Enter speaker name", text: $speakerName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.destructive)
                        .appCaption()
                }
                
                Button("Add Speaker") {
                    addSpeaker()
                }
                .buttonStyle(.borderedProminent)
                .disabled(speakerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                
                Spacer()
            }
            .padding(16)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            #endif
        }
    }
    
    private func addSpeaker() {
        let trimmedName = speakerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                _ = try await speakerIDService.addSpeaker(name: trimmedName)
                
                await MainActor.run {
                    self.isLoading = false
                    self.dismiss()
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
}

#Preview {
    AddSpeakerView(
        speakerIDService: SpeakerIDService()
    ) {}
} 
