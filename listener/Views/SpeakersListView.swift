import SwiftUI
import Foundation

struct SpeakersListView: View {
    @State private var speakers: [Speaker] = []
    @State private var pineconeSpeakers: [PineconeSpeaker] = []
    let speakerIDService: SpeakerIDService
    
    @State private var isRefreshing = false
    @State private var isPineconeLoading = false
    @State private var showingAddSpeaker = false
    @State private var showingAddPineconeSpeaker = false
    @State private var addEmbeddingItem: AddEmbeddingItem?
    @State private var newSpeakerName = ""
    @State private var errorMessage = ""
    @State private var selectedSegment = 0
    
    struct AddEmbeddingItem: Identifiable {
        let id = UUID()
        let speakerName: String
    }
    
    var body: some View {
        AppScrollContainer(spacing: 20) {
            // Header with segmented control
            VStack(spacing: 16) {
                HStack {
                    Text("Speaker Management")
                        .appHeadline()
                    
                    Spacer()
                    
                    HStack(spacing: AppSpacing.small) {
                        // Add button
                        Button(action: {
                            if selectedSegment == 0 {
                                showingAddSpeaker = true
                            } else {
                                showingAddPineconeSpeaker = true
                            }
                        }) {
                            Image(systemName: AppIcons.add)
                                .font(.title2)
                                .foregroundColor(.success)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Segmented control
                Picker("View Type", selection: $selectedSegment) {
                    Text("Conversation Speakers (\(speakers.count))").tag(0)
                    Text("Voice Samples (\(pineconeSpeakers.count))").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding(.horizontal, AppSpacing.medium)
                
            // Content based on selected segment
            if selectedSegment == 0 {
                // Conversation Speakers
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
                            ) {
                                refreshSpeakers()
                            }
                        }
                    }
                }
                
                if isRefreshing {
                    AppLoadingState(message: "Loading speakers...")
                }
            } else {
                // Pinecone Voice Samples
                if pineconeSpeakers.isEmpty && !isPineconeLoading {
                    AppEmptyState(
                        icon: AppIcons.noSpeakers,
                        title: "No voice samples found",
                        subtitle: "Add voice samples to train speaker recognition"
                    )
                } else {
                    ForEach(pineconeSpeakers) { speaker in
                        PineconeSpeakerCard(
                            speaker: speaker,
                            onAddEmbedding: { speakerName in
                                addEmbeddingItem = AddEmbeddingItem(speakerName: speakerName)
                            },
                            onDeleteSpeaker: deletePineconeSpeaker,
                            onDeleteEmbedding: deletePineconeEmbedding
                        )
                    }
                }
                
                if isPineconeLoading {
                    AppLoadingState(message: "Loading voice samples...")
                }
            }
        }
        .refreshable {
            refreshAllData()
        }
        .sheet(isPresented: $showingAddSpeaker) {
            AddSpeakerView(
                speakerIDService: speakerIDService
            ) {
                showingAddSpeaker = false
                refreshSpeakers()
            }
        }
        .sheet(isPresented: $showingAddPineconeSpeaker) {
            PineconeAddSpeakerView {
                showingAddPineconeSpeaker = false
                refreshPineconeSpeakers()
            }
        }
        .sheet(item: $addEmbeddingItem) { item in
            PineconeAddEmbeddingView(
                speakerName: item.speakerName
            ) {
                addEmbeddingItem = nil
                refreshPineconeSpeakers()
            }
        }
        .onAppear {
            refreshAllData()
        }
    }
    
    private func refreshAllData() {
        refreshSpeakers()
        refreshPineconeSpeakers()
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
    
    private func refreshPineconeSpeakers() {
        isPineconeLoading = true
        
        Task {
            do {
                let url = URL(string: "\(AppConstants.baseURL)/api/pinecone/speakers")!
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                if httpResponse.statusCode == 200 {
                    let speakersResponse = try JSONDecoder().decode(PineconeSpeakersResponse.self, from: data)
                    
                    await MainActor.run {
                        self.pineconeSpeakers = speakersResponse.speakers
                        self.isPineconeLoading = false
                    }
                } else {
                    throw URLError(.badServerResponse)
                }
            } catch {
                print("❌ Error loading Pinecone speakers: \(error)")
                await MainActor.run {
                    self.isPineconeLoading = false
                    self.pineconeSpeakers = []
                }
            }
        }
    }
    
    private func deletePineconeSpeaker(_ speakerName: String) {
        Task {
            do {
                let url = URL(string: "\(AppConstants.baseURL)/api/pinecone/speakers/\(speakerName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? speakerName)")!
                var request = URLRequest(url: url)
                request.httpMethod = "DELETE"
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                
                await MainActor.run {
                    self.refreshPineconeSpeakers()
                }
            } catch {
                print("❌ Error deleting Pinecone speaker: \(error)")
            }
        }
    }
    
    private func deletePineconeEmbedding(_ embeddingId: String) {
        Task {
            do {
                let url = URL(string: "\(AppConstants.baseURL)/api/pinecone/embeddings/\(embeddingId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? embeddingId)")!
                var request = URLRequest(url: url)
                request.httpMethod = "DELETE"
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                
                await MainActor.run {
                    self.refreshPineconeSpeakers()
                }
            } catch {
                print("❌ Error deleting Pinecone embedding: \(error)")
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
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(speaker.name)
                            .appHeadline()
                        
                        // Pinecone connection status icon
                        Image(systemName: isLinkedToPinecone ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isLinkedToPinecone ? .success : .secondaryText)
                            .font(.caption)
                    }
                    
                    // Show linked Pinecone name if available
                    if let pineconeSpeekerName = speaker.pinecone_speaker_name {
                        Text("linked to: \(pineconeSpeekerName)")
                            .appCaption()
                            .foregroundColor(.success)
                    }
                    
                    HStack(spacing: 12) {
                        if let utteranceCount = speaker.utterance_count {
                            Text("\(utteranceCount) utterances")
                                .appCaption()
                        }
                        
                        if let totalDuration = speaker.total_duration {
                            Text(DurationUtilities.formatDurationCompact(TimeInterval(totalDuration)))
                                .appCaption()
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: AppSpacing.small) {
                    // Pinecone link/unlink button (leftmost)
                    if isLinking {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if isLinkedToPinecone {
                        Button(action: {
                            unlinkFromPinecone()
                        }) {
                            Image(systemName: "link.slash")
                                .font(.title2)
                                .foregroundColor(.destructive)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: {
                            loadPineconeSpeekersAndShowPicker()
                        }) {
                            Image(systemName: "link")
                                .font(.title2)
                                .foregroundColor(.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: {
                        editedName = speaker.name
                        showingEditName = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.title2)
                            .foregroundColor(.accent)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        showingDetails = true
                    }) {
                        Image(systemName: "info.circle")
                            .font(.title2)
                            .foregroundColor(.success)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color.lightGrayBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
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
                    AppInfoCard {
                        VStack(spacing: 16) {
                            AppSpeakerAvatar(speakerName: speaker.name, size: 80)
                            
                            Text(speaker.name)
                                .font(.title)
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Stats
                    AppInfoCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Statistics")
                                .appHeadline()
                            
                            HStack(spacing: 20) {
                                StatItem(
                                    icon: "text.bubble",
                                    title: "Utterances",
                                    value: "\(speaker.utterance_count ?? 0)"
                                )
                                
                                StatItem(
                                    icon: "clock",
                                    title: "Total Duration",
                                    value: DurationUtilities.formatDurationCompact(TimeInterval(speaker.total_duration ?? 0))
                                )
                                
                                if let utteranceCount = speaker.utterance_count,
                                   let totalDuration = speaker.total_duration,
                                   utteranceCount > 0 {
                                    StatItem(
                                        icon: "speedometer",
                                        title: "Avg Duration",
                                        value: DurationUtilities.formatDurationCompact(TimeInterval(totalDuration / utteranceCount))
                                    )
                                }
                            }
                        }
                    }
                    
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
                    .appTitle()
                    .padding(.top)
                
                if isLoading || (!hasCompletedInitialLoad && availableSpeekers.isEmpty) {
                    AppLoadingState(message: "Loading Pinecone speakers...")
                        .frame(maxHeight: .infinity)
                } else if availableSpeekers.isEmpty {
                    VStack(spacing: 16) {
                        AppEmptyState(
                            icon: "person.2.slash",
                            title: "No Pinecone speakers found",
                            subtitle: "Enter the Pinecone speaker name manually"
                        )
                        
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
                            .appHeadline()
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(availableSpeekers, id: \.self) { speakerName in
                                    HStack {
                                        AppSpeakerAvatar(speakerName: speakerName, size: 32)
                                        
                                        Text(speakerName)
                                            .appSubtitle()
                                        
                                        Spacer()
                                        
                                        if selectedSpeeker == speakerName {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.success)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedSpeeker == speakerName ? 
                                        Color.success.opacity(0.1) : Color.clear
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
                    .background(Color.buttonSecondaryBackground)
                    .foregroundColor(.buttonSecondaryText)
                    .cornerRadius(8)
                    
                    Button("Link Speaker") {
                        let speakerName = useManualEntry ? manualSpeakerName : selectedSpeeker
                        onLink(speakerName)
                        onCancel()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(canLink ? Color.success : Color.buttonSecondaryBackground)
                    .foregroundColor(canLink ? .white : .buttonSecondaryText)
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
                        .appHeadline()
                    
                    Text("\(speaker.embeddings.count) voice samples")
                        .appCaption()
                }
                
                Spacer()
                
                HStack(spacing: AppSpacing.small) {
                    if !speaker.embeddings.isEmpty {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isExpanded.toggle()
                            }
                        }) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.title2)
                                .foregroundColor(.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: {
                        onAddEmbedding(speaker.name)
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .foregroundColor(.success)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .font(.title2)
                            .foregroundColor(.destructive)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if !speaker.embeddings.isEmpty && isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Embeddings:")
                        .appSubtitle()
                    
                    ForEach(speaker.embeddings) { embedding in
                        HStack {
                            Text(embedding.id)
                                .appCaption()
                            
                            Spacer()
                            
                            Button(action: {
                                onDeleteEmbedding(embedding.id)
                            }) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.destructive)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color.lightGrayBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cardBorder, lineWidth: 1)
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
                                .foregroundColor(Color.accent)
                        }
                        Spacer()
                    }
                }
            }
            
            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundColor(Color.destructive)
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
        
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"speaker_name\"\r\n\r\n".data(using: .utf8)!)
        formData.append("\(speakerName)\r\n".data(using: .utf8)!)
        
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"audio_file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        formData.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!)
        formData.append(audioData)
        formData.append("\r\n".data(using: .utf8)!)
        
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
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(Color.accent)
                        .font(.title)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Adding voice sample for:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(speakerName)
                            .font(.headline)
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
                                .foregroundColor(Color.accent)
                        }
                        Spacer()
                    }
                }
            }
            
            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundColor(Color.destructive)
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
        
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"speaker_name\"\r\n\r\n".data(using: .utf8)!)
        formData.append("\(speakerName)\r\n".data(using: .utf8)!)
        
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"audio_file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        formData.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!)
        formData.append(audioData)
        formData.append("\r\n".data(using: .utf8)!)
        
        formData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return formData
    }
}

#Preview {
    SpeakersListView(
        speakerIDService: SpeakerIDService()
    )
}
