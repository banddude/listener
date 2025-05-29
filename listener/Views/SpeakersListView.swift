import SwiftUI
import Foundation

struct SpeakersListView: View {
    @State private var speakers: [Speaker] = []
    let speakerIDService: SpeakerIDService
    
    @State private var isRefreshing = false
    @State private var showingAddSpeaker = false
    @State private var newSpeakerName = ""
    @State private var errorMessage = ""
    
    var body: some View {
        AppScrollContainer(spacing: 20) {
            // Header
            AppSectionHeader(
                title: "Speakers (\(speakers.count))",
                actionIcon: AppIcons.add,
                actionColor: .success
            )                { showingAddSpeaker = true }
                
                // Speakers List
                if speakers.isEmpty && !isRefreshing {
                    AppEmptyState(
                        icon: AppIcons.noSpeakers,
                        title: "No speakers found",
                        subtitle: "Speakers will appear here after processing conversations"
                    )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(speakers, id: \.id) { speaker in
                            SpeakerCard(
                                speaker: speaker,
                                speakerIDService: speakerIDService
                            )                                {
                                    refreshSpeakers()
                                }
                        }
                    }
                }
                
                if isRefreshing {
                    AppLoadingState(message: "Loading speakers...")
                }
        }
        .refreshable {
            refreshSpeakers()
        }
        .sheet(isPresented: $showingAddSpeaker) {
            AddSpeakerView(
                speakerIDService: speakerIDService
            )                {
                    showingAddSpeaker = false
                    refreshSpeakers()
                }
        }
        .onAppear {
            refreshSpeakers()
        }
    }
    
    private func refreshSpeakers() {
        isRefreshing = true
        
        Task {
            do {
                let loadedSpeakers = try await speakerIDService.getSpeakers()
                print("✅ Successfully loaded \(loadedSpeakers.count) speakers")
                
                await MainActor.run {
                    self.speakers = loadedSpeakers
                    self.isRefreshing = false
                }
            } catch {
                print("❌ Error loading speakers: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to load speakers: \(error.localizedDescription)"
                    self.isRefreshing = false
                }
            }
        }
    }
}

struct SpeakerCard: View {
    let speaker: Speaker
    let speakerIDService: SpeakerIDService
    let onSpeakerUpdated: () -> Void
    
    @State private var showingDetails = false
    @State private var showingEditName = false
    @State private var showingPineconeLink = false
    @State private var editedName = ""
    @State private var selectedPineconeSpeekerName = ""
    @State private var availablePineconeSpeekers: [String] = []
    @State private var isLinking = false
    @State private var isLoadingPineconeSpeekers = false
    
    var isLinkedToPinecone: Bool {
        speaker.pinecone_speaker_name != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Speaker Avatar
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(speaker.name.prefix(1)).uppercased())
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.blue)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(speaker.name)
                            .font(.headline)
                        
                        // Pinecone connection status icon
                        Image(systemName: isLinkedToPinecone ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isLinkedToPinecone ? .green : .gray)
                            .font(.caption)
                    }
                    
                    // Show linked Pinecone name if available
                    if let pineconeSpeekerName = speaker.pinecone_speaker_name {
                        Text("linked to: \(pineconeSpeekerName)")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    
                    HStack(spacing: 12) {
                        if let utteranceCount = speaker.utterance_count {
                            Text("\(utteranceCount) utterances")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let totalDuration = speaker.total_duration {
                            Text(formatDuration(totalDuration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Button(action: {
                            editedName = speaker.name
                            showingEditName = true
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            showingDetails = true
                        }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Pinecone link/unlink button
                    if isLinkedToPinecone {
                        Button(action: {
                            unlinkFromPinecone()
                        }) {
                            if isLinking {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Text("Unlink")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isLinking)
                    } else {
                        Button(action: {
                            loadPineconeSpeekersAndShowPicker()
                        }) {
                            if isLinking {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Text("Link to Pinecone")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isLinking)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
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
        .sheet(isPresented: $showingPineconeLink) {
            PineconeSpeakerPickerView(
                availableSpeekers: availablePineconeSpeekers,
                selectedSpeeker: $selectedPineconeSpeekerName,
                isLoading: isLoadingPineconeSpeekers,
                onLink: { speakerName in
                    linkToPinecone(speakerName: speakerName)
                },
                onCancel: {
                    showingPineconeLink = false
                }
            )
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        if seconds >= 60 {
            let minutes = seconds / 60
            let secs = seconds % 60
            return "\(minutes)m \(secs)s"
        } else {
            return "\(seconds)s"
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
                await MainActor.run {
                    onSpeakerUpdated()
                }
            } catch {
                print("❌ Failed to update speaker name: \(error)")
            }
        }
    }
    
    private func linkToPinecone(speakerName: String) {
        isLinking = true
        Task {
            do {
                try await speakerIDService.linkSpeakerToPinecone(
                    speakerId: speaker.id,
                    pineconeSpeekerName: speakerName.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                print("✅ Speaker linked to Pinecone successfully")
                await MainActor.run {
                    isLinking = false
                    selectedPineconeSpeekerName = speakerName
                    showingPineconeLink = false
                    onSpeakerUpdated()
                }
            } catch {
                print("❌ Failed to link speaker to Pinecone: \(error)")
                await MainActor.run {
                    isLinking = false
                }
            }
        }
    }
    
    private func unlinkFromPinecone() {
        isLinking = true
        Task {
            do {
                try await speakerIDService.unlinkSpeakerFromPinecone(speakerId: speaker.id)
                print("✅ Speaker unlinked from Pinecone successfully")
                await MainActor.run {
                    isLinking = false
                    onSpeakerUpdated()
                }
            } catch {
                print("❌ Failed to unlink speaker from Pinecone: \(error)")
                await MainActor.run {
                    isLinking = false
                }
            }
        }
    }
    
    private func loadPineconeSpeekersAndShowPicker() {
        // Set loading state FIRST, before showing picker
        isLoadingPineconeSpeekers = true
        availablePineconeSpeekers = [] // Ensure empty list
        selectedPineconeSpeekerName = "" // Reset selection
        
        // Show picker after setting loading state
        showingPineconeLink = true
        
        Task {
            do {
                print("🔍 Loading Pinecone speakers...")
                let speakers = try await speakerIDService.getPineconeSpeekers()
                print("✅ Loaded \(speakers.count) Pinecone speakers: \(speakers)")
                await MainActor.run {
                    availablePineconeSpeekers = speakers
                    isLoadingPineconeSpeekers = false
                    if speakers.isEmpty {
                        print("⚠️ No Pinecone speakers found, showing manual entry")
                    }
                }
            } catch {
                print("❌ Failed to load Pinecone speakers: \(error)")
                await MainActor.run {
                    isLoadingPineconeSpeekers = false
                    availablePineconeSpeekers = []
                    // Picker is already showing, user can use manual entry
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
        if seconds >= 60 {
            let minutes = seconds / 60
            let secs = seconds % 60
            return "\(minutes)m \(secs)s"
        } else {
            return "\(seconds)s"
        }
    }
}

struct PineconeSpeakerPickerView: View {
    let availableSpeekers: [String]
    @Binding var selectedSpeeker: String
    let isLoading: Bool
    let onLink: (String) -> Void
    let onCancel: () -> Void
    
    @State private var manualSpeakerName = ""
    @State private var useManualEntry = false
    @State private var hasCompletedInitialLoad = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Link to Pinecone Speaker")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                if isLoading || (!hasCompletedInitialLoad && availableSpeekers.isEmpty) {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading Pinecone speakers...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else if availableSpeekers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("No Pinecone speakers found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Enter the Pinecone speaker name manually")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        TextField("Pinecone Speaker Name", text: $manualSpeakerName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onAppear {
                                useManualEntry = true
                            }
                    }
                    .padding()
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Select a Pinecone speaker:")
                            .font(.headline)
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(availableSpeekers, id: \.self) { speakerName in
                                    HStack {
                                        Circle()
                                            .fill(Color.green.opacity(0.2))
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Text(String(speakerName.prefix(1)).uppercased())
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundColor(.green)
                                            )
                                        
                                        Text(speakerName)
                                            .font(.subheadline)
                                        
                                        Spacer()
                                        
                                        if selectedSpeeker == speakerName {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedSpeeker == speakerName ? 
                                        Color.green.opacity(0.1) : Color.clear
                                    )
                                    .cornerRadius(8)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedSpeeker = speakerName
                                        useManualEntry = false
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Manual entry option
                        Toggle("Enter name manually", isOn: $useManualEntry)
                            .padding(.horizontal)
                        
                        if useManualEntry {
                            TextField("Pinecone Speaker Name", text: $manualSpeakerName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                        }
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                    
                    Button("Link Speaker") {
                        let speakerName = useManualEntry ? manualSpeakerName : selectedSpeeker
                        onLink(speakerName)
                        onCancel()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(canLink ? Color.green : Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(!canLink)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Link to Pinecone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
            .onChange(of: isLoading) { oldValue, newValue in
                if oldValue == true && newValue == false {
                    hasCompletedInitialLoad = true
                }
            }
        }
    }
    
    private var canLink: Bool {
        if useManualEntry {
            return !manualSpeakerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return !selectedSpeeker.isEmpty
        }
    }
}

#Preview {
    SpeakersListView(
        speakerIDService: SpeakerIDService()
    )
}
