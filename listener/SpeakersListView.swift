import SwiftUI
import Foundation

struct SpeakersListView: View {
    let speakers: [Speaker]
    let speakerIDService: SpeakerIDService
    
    @State private var isRefreshing = false
    @State private var showingAddSpeaker = false
    @State private var newSpeakerName = ""
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Speakers")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Add Speaker") {
                    showingAddSpeaker = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding()
            
            // Speakers List
            if speakers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No speakers found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Speakers will appear here after processing conversations")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(speakers, id: \.id) { speaker in
                        SpeakerRow(
                            speaker: speaker,
                            speakerIDService: speakerIDService
                        )
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    await refreshSpeakers()
                }
            }
            
            // Error Message
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding()
            }
        }
        .sheet(isPresented: $showingAddSpeaker) {
            AddSpeakerView(
                speakerIDService: speakerIDService,
                onSpeakerAdded: {
                    Task {
                        await refreshSpeakers()
                    }
                }
            )
        }
    }
    
    private func refreshSpeakers() async {
        isRefreshing = true
        // Parent view will handle refresh through loadData()
        try? await Task.sleep(nanoseconds: 500_000_000) // Brief delay for UX
        isRefreshing = false
    }
}

struct SpeakerRow: View {
    let speaker: Speaker
    let speakerIDService: SpeakerIDService
    
    @State private var showingDetails = false
    @State private var showingEditName = false
    @State private var editedName = ""
    
    var body: some View {
        HStack(spacing: 12) {
            // Speaker Avatar
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(speaker.name.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                // Speaker name
                Text(speaker.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Stats
                HStack(spacing: 16) {
                    if let utteranceCount = speaker.utterance_count {
                        Label("\(utteranceCount) utterances", systemImage: "text.bubble")
                    }
                    
                    if let totalDuration = speaker.total_duration {
                        let minutes = totalDuration / 60
                        let seconds = totalDuration % 60
                        Label("\(minutes):\(String(format: "%02d", seconds))", systemImage: "clock")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                Button("Edit") {
                    editedName = speaker.name
                    showingEditName = true
                }
                .font(.caption)
                .foregroundColor(.blue)
                
                Button("Details") {
                    showingDetails = true
                }
                .font(.caption)
                .foregroundColor(.green)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .sheet(isPresented: $showingDetails) {
            SpeakerDetailView(
                speaker: speaker,
                speakerIDService: speakerIDService
            )
        }
        .alert("Edit Speaker Name", isPresented: $showingEditName) {
            TextField("Speaker Name", text: $editedName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                updateSpeakerName()
            }
        }
    }
    
    private func updateSpeakerName() {
        guard !editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        Task {
            do {
                _ = try await speakerIDService.updateSpeaker(
                    speakerId: speaker.id,
                    newName: editedName.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                print("✅ Speaker name updated successfully")
            } catch {
                print("❌ Failed to update speaker name: \(error)")
            }
        }
    }
}

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
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Speaker Name")
                        .font(.headline)
                    
                    TextField("Enter speaker name", text: $speakerName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
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
            .padding()
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

struct SpeakerDetailView: View {
    let speaker: Speaker
    let speakerIDService: SpeakerIDService
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Speaker Info
                    VStack(spacing: 16) {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(String(speaker.name.prefix(1)).uppercased())
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.blue)
                            )
                        
                        Text(speaker.name)
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Stats
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Statistics")
                            .font(.headline)
                        
                        HStack(spacing: 20) {
                            StatItem(
                                icon: "text.bubble",
                                title: "Utterances",
                                value: "\(speaker.utterance_count ?? 0)"
                            )
                            
                            StatItem(
                                icon: "clock",
                                title: "Total Duration",
                                value: formatDuration(speaker.total_duration ?? 0)
                            )
                            
                            if let utteranceCount = speaker.utterance_count,
                               let totalDuration = speaker.total_duration,
                               utteranceCount > 0 {
                                StatItem(
                                    icon: "speedometer",
                                    title: "Avg Duration",
                                    value: formatDuration(totalDuration / utteranceCount)
                                )
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Speaker Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            #endif
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return "\(minutes):\(String(format: "%02d", secs))"
    }
}

#Preview {
    SpeakersListView(
        speakers: [
            Speaker(id: "1", name: "Alice", utterance_count: 15, total_duration: 120),
            Speaker(id: "2", name: "Bob", utterance_count: 8, total_duration: 90)
        ],
        speakerIDService: SpeakerIDService()
    )
} 