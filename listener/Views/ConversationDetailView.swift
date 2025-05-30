import SwiftUI
import Foundation
import AVFoundation

struct ConversationDetailView: View {
    let conversationId: String
    let speakerIDService: SpeakerIDService
    let onConversationUpdated: (() -> Void)?
    
    @State private var conversationSummary: BackendConversationSummary?
    @State private var conversationDetail: ConversationDetail?
    @State private var isLoading = true
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                AppLoadingState(message: "Loading conversation...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let summary = conversationSummary, let detail = conversationDetail {
                ConversationDetailContent(
                    conversationId: conversationId,
                    initialSummary: summary,
                    initialDetail: detail,
                    speakerIDService: speakerIDService,
                    onConversationUpdated: onConversationUpdated,
                    onNeedsFullReload: {
                        Task { await loadFullConversationData() }
                    }
                )
            } else {
                // Error state
                VStack(spacing: 16) {
                    AppEmptyState(
                        icon: AppIcons.error,
                        title: "Failed to load conversation",
                        subtitle: errorMessage.isEmpty ? "Please try again" : errorMessage
                    )
                    
                    Button("Retry") {
                        Task { await loadFullConversationData() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            Task { await loadFullConversationData() }
        }
    }
    
    private func loadFullConversationData() async {
        isLoading = true
        errorMessage = ""
        
        do {
            let detail = try await speakerIDService.getConversationDetails(
                conversationId: conversationId
            )
            
            let summary = BackendConversationSummary(
                id: detail.id,
                conversation_id: conversationId,
                created_at: detail.date_processed,
                duration: detail.duration_seconds,
                display_name: detail.display_name ?? "Conversation",
                speaker_count: Array(Set(detail.utterances.map { $0.speaker_name })).count,
                utterance_count: detail.utterances.count,
                speakers: Array(Set(detail.utterances.map { $0.speaker_name }))
            )

            await MainActor.run {
                self.conversationSummary = summary
                self.conversationDetail = detail
                self.isLoading = false
                
                // Debug: Print conversation details and utterance URLs
                print("🎯 Loaded conversation with \(detail.utterances.count) utterances:")
                print("   Duration from detail: \(detail.duration_seconds ?? -1)s")
                for (index, utterance) in detail.utterances.enumerated() {
                    print("  [\(index)] Speaker: \(utterance.speaker_name)")
                    print("      Audio URL: \(utterance.audio_url)")
                    print("      Start: \(utterance.start_time), End: \(utterance.end_time)")
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

struct ConversationDetailContent: View {
    let conversationId: String
    @State var currentSummary: BackendConversationSummary
    @State var currentDetail: ConversationDetail
    let speakerIDService: SpeakerIDService
    let onConversationUpdated: (() -> Void)?
    let onNeedsFullReload: () -> Void
    
    @State private var selectedSpeaker: String?
    @State private var audioPlayer: AVPlayer?
    @State private var currentlyPlayingURL: String?
    @State private var isPlayingFullConversation = false
    @State private var currentUtteranceIndex: Int = 0
    @State private var timeObserver: Any?
    @State private var isEditingConversationName = false
    @State private var editedConversationName: String
    @State private var cachedSpeakers: [Speaker] = []
    @State private var isLoadingSpeakers = false
    @State private var isRefreshing = false
    
    private var createdDate: Date? {
        guard let createdAt = currentSummary.created_at else { return nil }
        return DateUtilities.parseISODate(createdAt)
    }
    
    private var uniqueSpeakers: [String] {
        Array(Set(currentDetail.utterances.map { $0.speaker_name })).sorted()
    }
    
    init(conversationId: String, 
         initialSummary: BackendConversationSummary, 
         initialDetail: ConversationDetail,
         speakerIDService: SpeakerIDService,
         onConversationUpdated: (() -> Void)?,
         onNeedsFullReload: @escaping () -> Void) {
        self.conversationId = conversationId
        _currentSummary = State(initialValue: initialSummary)
        _currentDetail = State(initialValue: initialDetail)
        self.speakerIDService = speakerIDService
        self.onConversationUpdated = onConversationUpdated
        self.onNeedsFullReload = onNeedsFullReload
        _editedConversationName = State(initialValue: initialSummary.display_name ?? "Untitled Conversation")
    }
    
    var body: some View {
        AppScrollContainer(spacing: 20) {
                // Refresh indicator
                if isRefreshing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Updating conversation...")
                            .appCaption()
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.accentLight)
                    .cornerRadius(8)
                }
                
                // Conversation Title Header with Play Button
                AppInfoCard {
                    VStack(alignment: .leading, spacing: 12) {
                        // Title with edit functionality
                        HStack {
                            if isEditingConversationName {
                                TextField("Conversation name", text: $editedConversationName)
                                    .appTitle()
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onSubmit {
                                        saveConversationName()
                                    }
                            } else {
                                Text(currentSummary.display_name ?? "Untitled Conversation")
                                    .appTitle()
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Spacer()
                            
                            // Edit button for conversation name
                            Button(action: {
                                if isEditingConversationName {
                                    saveConversationName()
                                } else {
                                    startEditingConversationName()
                                }
                            }) {
                                Image(systemName: isEditingConversationName ? "checkmark.circle.fill" : "pencil")
                                    .font(.title2)
                                    .foregroundColor(.accent)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Date and play button row
                        HStack {
                            if let date = createdDate {
                                Text(DateUtilities.formatConversationDate(date))
                                    .appSubtitle()
                            }
                            
                            Spacer()
                            
                            // Full conversation play button
                            if !currentDetail.utterances.isEmpty {
                                Button(action: {
                                    if isPlayingFullConversation {
                                        stopSequentialPlayback()
                                    } else {
                                        startSequentialPlayback()
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: isPlayingFullConversation ? "pause.circle.fill" : "play.circle.fill")
                                            .font(.title2)
                                        Text(isPlayingFullConversation ? "Pause" : (selectedSpeaker != nil ? "Play Filtered" : "Play All"))
                                            .appSubtitle()
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.accent)
                                    .cornerRadius(20)
                                }
                            }
                        }
                        
                        if isPlayingFullConversation {
                            Text("Playing utterance \(currentUtteranceIndex + 1) of \(selectedSpeaker != nil ? filteredUtterances.count : currentDetail.utterances.count)")
                                .appCaption()
                        }
                    }
                }
                
                // Stats Card
                AppInfoCard {
                    HStack(spacing: 0) {
                        StatItem(
                            icon: "clock",
                            title: "Duration",
                            value: DurationUtilities.formatDurationCompact(TimeInterval(currentDetail.duration_seconds ?? currentSummary.duration ?? 0))
                        )
                        .frame(maxWidth: .infinity)
                        
                        StatItem(
                            icon: "person.2",
                            title: "Speakers",
                            value: "\(uniqueSpeakers.count)"
                        )
                        .frame(maxWidth: .infinity)
                        
                        StatItem(
                            icon: "text.bubble",
                            title: "Utterances",
                            value: "\(currentDetail.utterances.count)"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 8)
                }
                
                // Speaker Filter
                if !uniqueSpeakers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Filter by Speaker")
                            .appHeadline()
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                SpeakerFilterButton(
                                    title: "All",
                                    isSelected: selectedSpeaker == nil
                                ) { 
                                        selectedSpeaker = nil 
                                }
                                
                                ForEach(uniqueSpeakers, id: \.self) { speaker in
                                    SpeakerFilterButton(
                                        title: speaker,
                                        isSelected: selectedSpeaker == speaker
                                    ) { 
                                            selectedSpeaker = speaker 
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Utterances
                if currentDetail.utterances.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("No utterances found")
                            .appHeadline()
                            .foregroundColor(.secondaryText)
                        
                        Text("This conversation hasn't been processed yet")
                            .appSubtitle()
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredUtterances, id: \.id) { utterance in
                            let isCurrentlyPlaying = currentlyPlayingURL == utterance.audio_url
                            
                            UtteranceRow(
                                utterance: utterance,
                                isPlaying: isCurrentlyPlaying,
                                onPlayTap: {
                                    playIndividualUtterance(utterance)
                                },
                                onUtteranceUpdate: { updatedUtterance in
                                    updateUtterance(updatedUtterance)
                                },
                                cachedSpeakers: cachedSpeakers,
                                currentConversationDetail: currentDetail,
                                onNeedsFullReload: onNeedsFullReload
                            )
                            .environmentObject(speakerIDService)
                        }
                    }
                }
        }
        .onDisappear {
            cleanupAudioPlayer()
        }
        .onAppear {
            preloadSpeakers()
        }
    }
    
    private var filteredUtterances: [SpeakerIDUtterance] {
        if let selectedSpeaker = selectedSpeaker {
            let filtered = currentDetail.utterances.filter { $0.speaker_name == selectedSpeaker }
            return filtered
        }
        return currentDetail.utterances
    }
    
    private func startSequentialPlayback() {
        print("🎵 Starting sequential conversation playback")
        cleanupAudioPlayer()
        currentUtteranceIndex = 0
        isPlayingFullConversation = true
        
        let utterancesToPlay = filteredUtterances
        guard !utterancesToPlay.isEmpty else {
            print("❌ No utterances to play")
            return
        }
        
        print("🎯 Playing \(utterancesToPlay.count) utterances (filtered: \(selectedSpeaker != nil))")
        playCurrentUtterance()
    }
    
    private func playCurrentUtterance() {
        let utterancesToPlay = filteredUtterances
        guard currentUtteranceIndex < utterancesToPlay.count else {
            print("✅ Sequential conversation playback completed")
            stopSequentialPlayback()
            return
        }
        
        let currentUtterance = utterancesToPlay[currentUtteranceIndex]
        print("🎵 Playing utterance [\(currentUtteranceIndex + 1)/\(utterancesToPlay.count)]: \(currentUtterance.speaker_name)")
        
        let fullURL = getFullAudioURL(currentUtterance.audio_url)
        guard let audioURL = URL(string: fullURL), audioURL.scheme != nil else {
            print("❌ Invalid audio URL: \(fullURL)")
            moveToNextUtterance()
            return
        }
        
        let playerItem = AVPlayerItem(url: audioURL)
        audioPlayer = AVPlayer(playerItem: playerItem)
        currentlyPlayingURL = currentUtterance.audio_url
        
        // Add completion observer only for this specific item
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            print("✅ Audio playback completed for utterance \(currentUtteranceIndex)")
            DispatchQueue.main.async {
                self.moveToNextUtterance()
            }
        }
        
        audioPlayer?.play()
    }
    
    private func moveToNextUtterance() {
        // Remove observers for current item
        if let currentItem = audioPlayer?.currentItem {
            NotificationCenter.default.removeObserver(
                self,
                name: .AVPlayerItemDidPlayToEndTime,
                object: currentItem
            )
        }
        
        currentUtteranceIndex += 1
        let utterancesToPlay = filteredUtterances
        
        if currentUtteranceIndex < utterancesToPlay.count && isPlayingFullConversation {
            playCurrentUtterance()
        } else {
            print("✅ Sequential conversation playback completed")
            stopSequentialPlayback()
        }
    }
    
    private func stopSequentialPlayback() {
        cleanupAudioPlayer()
        isPlayingFullConversation = false
        currentUtteranceIndex = 0
        currentlyPlayingURL = nil
    }
    
    private func playIndividualUtterance(_ utterance: SpeakerIDUtterance) {
        if currentlyPlayingURL == utterance.audio_url && !isPlayingFullConversation {
            // Already playing this individual utterance, pause it
            cleanupAudioPlayer()
            currentlyPlayingURL = nil
            return
        }
        
        cleanupAudioPlayer()
        isPlayingFullConversation = false
        
        let fullURL = getFullAudioURL(utterance.audio_url)
        guard let audioURL = URL(string: fullURL), audioURL.scheme != nil else {
            print("❌ Invalid audio URL: \(fullURL)")
            return
        }
        
        let playerItem = AVPlayerItem(url: audioURL)
        audioPlayer = AVPlayer(playerItem: playerItem)
        currentlyPlayingURL = utterance.audio_url
        
        // Add completion observer
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            DispatchQueue.main.async {
                self.currentlyPlayingURL = nil
            }
        }
        
        audioPlayer?.play()
    }
    
    private func cleanupAudioPlayer() {
        audioPlayer?.pause()
        
        // Remove time observer
        if let observer = timeObserver, let player = audioPlayer {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        // Remove all notification observers
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: nil)
        
        audioPlayer = nil
    }
    
    private func getFullAudioURL(_ urlString: String) -> String {
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return urlString
        }
        
        let baseURL = AppConstants.baseURL
        return baseURL + urlString
    }
    
    private func startEditingConversationName() {
        isEditingConversationName = true
    }
    
    private func saveConversationName() {
        guard editedConversationName != currentSummary.display_name else {
            isEditingConversationName = false
            return
        }
        
        Task {
            do {
                // Use the database ID (not conversation_id) for the API call
                try await speakerIDService.updateConversationName(
                    conversationId: currentSummary.id,
                    newName: editedConversationName
                )
                
                await MainActor.run {
                    // Update the summary (detail will be updated on next reload)
                    currentSummary.display_name = editedConversationName
                    isEditingConversationName = false
                }
                
                // Add a small delay to allow server cache to update before refreshing
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                await MainActor.run {
                    // Trigger a full server refresh of the conversations list
                    print("🔄 ConversationDetailView: Triggering server refresh after name update")
                    onConversationUpdated?()
                }
                
                print("✅ Successfully updated conversation name to: \(editedConversationName)")
            } catch {
                print("❌ Failed to update conversation name: \(error)")
                await MainActor.run {
                    // Reset to original name on error
                    editedConversationName = currentSummary.display_name ?? "Untitled Conversation"
                    isEditingConversationName = false
                }
            }
        }
    }
    
    private func updateUtterance(_ updatedUtterance: SpeakerIDUtterance) {
        print("📝 Updating utterance: \(updatedUtterance.id) - Speaker: \(updatedUtterance.speaker_name), Text: \(updatedUtterance.text)")
        
        // For all real utterance updates, make it synchronous so UI updates immediately
        Task {
            do {
                // Call the actual API to update the utterance
                _ = try await speakerIDService.updateUtterance(
                    utteranceId: updatedUtterance.id,
                    speakerId: updatedUtterance.speaker_id,
                    text: updatedUtterance.text
                )
                print("✅ Utterance successfully updated on server: \(updatedUtterance.id)")
                
                // Trigger full conversation reload with loading screen
                await MainActor.run {
                    onNeedsFullReload()
                }
            } catch {
                print("❌ Error updating utterance: \(error.localizedDescription)")
                // Still trigger reload to ensure UI consistency
                await MainActor.run {
                    onNeedsFullReload()
                }
            }
        }
    }
    
    private func preloadSpeakers() {
        // Load speakers in background without blocking UI
        guard !isLoadingSpeakers && cachedSpeakers.isEmpty else { return }
        
        isLoadingSpeakers = true
        Task {
            do {
                let speakers = try await speakerIDService.getAllSpeakersForSelection()
                await MainActor.run {
                    self.cachedSpeakers = speakers
                    self.isLoadingSpeakers = false
                    print("✅ Preloaded \(speakers.count) speakers for editing")
                }
            } catch {
                await MainActor.run {
                    self.isLoadingSpeakers = false
                    print("⚠️ Failed to preload speakers: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct SpeakerFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .appCaption()
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? Color.accent : Color.lightGrayBackground
                )
                .foregroundColor(isSelected ? .white : .primaryText)
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct UtteranceRow: View {
    @State var utterance: SpeakerIDUtterance
    let isPlaying: Bool
    let onPlayTap: () -> Void
    let onUtteranceUpdate: (SpeakerIDUtterance) -> Void
    let cachedSpeakers: [Speaker]
    let currentConversationDetail: ConversationDetail
    let onNeedsFullReload: () -> Void
    
    @State private var isEditingText = false
    @State private var isEditingSpeaker = false
    @State private var editedText = ""
    @State private var selectedSpeakerId = ""
    @State private var newSpeakerName = ""
    @State private var showingSpeakerPicker = false
    @State private var applyToAllUtterances = false
    @State private var isSavingEdit = false
    @State private var isPineconeToggling = false
    
    // Access to the SpeakerIDService through environment
    @EnvironmentObject private var speakerIDService: SpeakerIDService
    
    // Computed properties for safe access to Pinecone fields with defaults
    private var includedInPinecone: Bool {
        utterance.included_in_pinecone
    }
    
    private var utteranceEmbeddingId: String? {
        utterance.utterance_embedding_id
    }
    
    private var isValidAudioURL: Bool {
        let fullURL = getFullAudioURL(utterance.audio_url)
        guard let url = URL(string: fullURL), 
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()) else {
            return false
        }
        return true
    }
    
    private func getFullAudioURL(_ urlString: String) -> String {
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return urlString
        }
        
        let baseURL = AppConstants.baseURL
        return baseURL + urlString
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Speaker Avatar
            AppSpeakerAvatar(speakerName: utterance.speaker_name, size: 36)
                .overlay(
                    Circle()
                        .stroke(isPlaying ? Color.accent : Color.clear, lineWidth: 2)
                )
            
            VStack(alignment: .leading, spacing: 8) {
                // Speaker name row with inline edit functionality
                HStack {
                    // Tappable speaker name for editing
                    Text(utterance.speaker_name)
                        .appHeadline()
                        .onTapGesture {
                            startEditingSpeaker()
                        }
                    
                    // Pinecone inclusion toggle with loading state
                    HStack(spacing: 6) {
                        Text("Pinecone")
                            .appCaption()
                        
                        if isPineconeToggling {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Toggle("", isOn: Binding(
                                get: { includedInPinecone },
                                set: { _ in 
                                    isPineconeToggling = true
                                    togglePineconeInclusion() 
                                }
                            ))
                            .scaleEffect(0.8)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        print("🚨🚨🚨 BUTTON TAPPED! This should appear in logs!")
                        print("🚨🚨🚨 Speaker: \(utterance.speaker_name)")
                        print("🚨🚨🚨 Button is NOT disabled - action is running!")
                        print("🎯 DEBUG: UtteranceRow play button tapped for: \(utterance.speaker_name)")
                        print("🎯 DEBUG: Current isPlaying state: \(isPlaying)")
                        print("🎯 DEBUG: Audio URL: \(utterance.audio_url)")
                        print("🎯 DEBUG: About to call onPlayTap()")
                        onPlayTap()
                        print("🎯 DEBUG: onPlayTap() has been called")
                    }) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(isValidAudioURL ? .accent : .secondaryText)
                    }
                    .buttonStyle(.plain)
                    // .disabled(!isValidAudioURL) // TEMPORARILY DISABLED FOR DEBUG
                    
                    Text(utterance.start_time)
                        .appCaption()
                }
                
                // Utterance text with inline edit functionality
                VStack(alignment: .leading, spacing: 4) {
                    if isEditingText {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Utterance text", text: $editedText, axis: .vertical)
                                .appBody()
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(3...10)
                            
                            HStack {
                                Button("Cancel") {
                                    cancelTextEdit()
                                }
                                .appCaption()
                                
                                Spacer()
                                
                                Button("Save") {
                                    saveUtteranceText()
                                }
                                .appCaption()
                                .foregroundColor(.accent)
                            }
                        }
                    } else {
                        // Tappable utterance text for editing
                        Text(utterance.text)
                            .appBody()
                            .fixedSize(horizontal: false, vertical: true)
                            .onTapGesture {
                                startEditingText()
                            }
                    }
                }
                
                // Show audio URL status if invalid
                if !isValidAudioURL {
                    Text("⚠️ Audio not available")
                        .appCaption()
                        .foregroundColor(.warning)
                }
            }
        }
        .padding()
        .background(isPlaying ? Color.accentLight : Color.lightGrayBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isPlaying ? Color.accent : Color.cardBorder, lineWidth: 1)
        )
        .sheet(isPresented: $showingSpeakerPicker) {
            SpeakerPickerView(
                utterance: utterance,
                availableSpeakers: cachedSpeakers,
                selectedSpeakerId: $selectedSpeakerId,
                newSpeakerName: $newSpeakerName,
                applyToAllUtterances: $applyToAllUtterances,
                onSave: { selectedId, newName, applyToAll in
                    saveSpeakerSelection(selectedId: selectedId, newName: newName, applyToAll: applyToAll)
                },
                onCancel: {
                    showingSpeakerPicker = false
                    resetSpeakerEditingState()
                }
            )
        }
    }
    
    private func startEditingText() {
        isEditingText = true
        editedText = utterance.text
    }
    
    private func saveUtteranceText() {
        let newText = editedText
        
        // Show loading state
        isSavingEdit = true
        
        // Show loading state while updating
        Task {
            do {
                // Call the actual API to update the utterance
                _ = try await speakerIDService.updateUtterance(
                    utteranceId: utterance.id,
                    speakerId: nil,
                    text: newText
                )
                print("✅ Utterance text successfully updated on server: \(utterance.id)")
                
                await MainActor.run {
                    isSavingEdit = false
                    isEditingText = false
                    print("✅ Text edit completed - triggering full reload")
                    
                    // Trigger full conversation reload with loading screen
                    onNeedsFullReload()
                }
            } catch {
                print("❌ Error updating utterance text: \(error.localizedDescription)")
                await MainActor.run {
                    isSavingEdit = false
                    isEditingText = false
                    
                    // Still trigger reload to ensure UI consistency
                    onNeedsFullReload()
                }
            }
        }
    }
    
    private func cancelTextEdit() {
        isEditingText = false
        editedText = utterance.text
    }
    
    private func startEditingSpeaker() {
        isEditingSpeaker = true
        selectedSpeakerId = utterance.speaker_id
        newSpeakerName = ""
        applyToAllUtterances = false
        showingSpeakerPicker = true
    }
    
    private func saveSpeakerSelection(selectedId: String, newName: String, applyToAll: Bool) {
        // Show loading state
        isSavingEdit = true
        
        // Don't dismiss speaker picker immediately - wait for update to complete
        
        Task {
            var shouldReload = false
            
            do {
                let finalSpeakerId = selectedId
                var finalSpeakerName = ""
                
                // Find the speaker name from available speakers
                if let speaker = cachedSpeakers.first(where: { $0.id == selectedId }) {
                    finalSpeakerName = speaker.name
                } else {
                    finalSpeakerName = "Speaker \(selectedId)"
                }
                
                if applyToAll {
                    // Apply to all utterances by the current speaker IN THIS CONVERSATION ONLY
                    print("🔄 Applying speaker change to all utterances by \(utterance.speaker_name) in this conversation")
                    print("🎯 DEBUG: currentConversationDetail.conversation_id = \(currentConversationDetail.conversation_id)")
                    
                    // WORKAROUND: Since the API doesn't support conversation_id filtering for bulk updates,
                    // we'll filter and update utterances individually to ensure only this conversation is affected
                    let utterancesToUpdate = currentConversationDetail.utterances.filter { 
                        $0.speaker_id == utterance.speaker_id 
                    }
                    print("🎯 Found \(utterancesToUpdate.count) utterances by \(utterance.speaker_name) in this conversation to update")
                    
                    var updateCount = 0
                    for utteranceToUpdate in utterancesToUpdate {
                        do {
                            _ = try await speakerIDService.updateUtterance(
                                utteranceId: utteranceToUpdate.id,
                                speakerId: finalSpeakerId,
                                text: nil
                            )
                            updateCount += 1
                            print("✅ Updated utterance \(updateCount)/\(utterancesToUpdate.count): \(utteranceToUpdate.id)")
                        } catch {
                            print("❌ Failed to update utterance \(utteranceToUpdate.id): \(error.localizedDescription)")
                        }
                    }
                    
                    print("✅ Updated \(updateCount) utterances from speaker \(utterance.speaker_name) to \(finalSpeakerName) in this conversation only")
                    shouldReload = true
                } else {
                    // Update just this utterance
                    print("🔄 Starting single utterance speaker update: \(utterance.id) → \(finalSpeakerId)")
                    
                    _ = try await speakerIDService.updateUtterance(
                        utteranceId: utterance.id,
                        speakerId: finalSpeakerId,
                        text: nil
                    )
                    print("✅ Updated single utterance to speaker: \(finalSpeakerName)")
                    shouldReload = true
                }
            } catch {
                print("❌ Error updating speaker: \(error.localizedDescription)")
                shouldReload = true // Still reload to ensure UI consistency
            }
            
            // ALWAYS clean up UI and reload, regardless of success/failure
            await MainActor.run {
                isSavingEdit = false
                showingSpeakerPicker = false
                resetSpeakerEditingState()
                
                if shouldReload {
                    print("✅ Speaker edit completed - triggering full reload")
                    onNeedsFullReload()
                } else {
                    print("⚠️ Speaker edit had issues but still triggering reload for UI consistency")
                    onNeedsFullReload()
                }
            }
        }
    }
    
    private func resetSpeakerEditingState() {
        isEditingSpeaker = false
        selectedSpeakerId = ""
        newSpeakerName = ""
        applyToAllUtterances = false
        isSavingEdit = false
    }
    
    private func togglePineconeInclusion() {
        let newStatus = !includedInPinecone
        print("🎯 Toggling Pinecone inclusion for utterance \(utterance.id) from \(includedInPinecone) to \(newStatus)")
        
        Task {
            do {
                let response = try await speakerIDService.toggleUtterancePineconeInclusion(
                    utteranceId: utterance.id,
                    includeInPinecone: newStatus
                )
                
                await MainActor.run {
                    isPineconeToggling = false
                    print("✅ Pinecone inclusion toggle completed: \(response.message)")
                    
                    // Trigger full conversation reload to refresh the inclusion status
                    onNeedsFullReload()
                }
            } catch {
                print("❌ Error toggling Pinecone inclusion: \(error.localizedDescription)")
                await MainActor.run {
                    isPineconeToggling = false
                    
                    // Still trigger reload to ensure UI consistency
                    onNeedsFullReload()
                }
            }
        }
    }
}

struct SpeakerPickerView: View {
    let utterance: SpeakerIDUtterance
    let availableSpeakers: [Speaker]
    @Binding var selectedSpeakerId: String
    @Binding var newSpeakerName: String
    @Binding var applyToAllUtterances: Bool
    let onSave: (String, String, Bool) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Utterance Preview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Edit Speaker Assignment")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Utterance Text:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text(utterance.text)
                            .font(.body)
                            .padding(12)
                            .background(Color.lightGrayBackground)
                            .cornerRadius(8)
                        
                        Text("Current Speaker: \(utterance.speaker_name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                Divider()
                
                // Speaker Selection Form
                VStack(alignment: .leading, spacing: 16) {
                    // Speaker selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select Speaker")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal)
                            .padding(.top, 16)
                        
                        if availableSpeakers.isEmpty {
                            Text("No speakers available")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            List(availableSpeakers, id: \.id) { speaker in
                                HStack {
                                    AppSpeakerAvatar(speakerName: speaker.name, size: 32)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(speaker.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        if let utteranceCount = speaker.utterance_count {
                                            Text("\(utteranceCount) utterances")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedSpeakerId == speaker.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.accent)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedSpeakerId = speaker.id
                                }
                            }
                            .listStyle(PlainListStyle())
                        }
                    }
                    
                    // Apply to all option
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Apply to all utterances by \"\(utterance.speaker_name)\" in this conversation", isOn: $applyToAllUtterances)
                            .appSubtitle()
                        
                        if applyToAllUtterances {
                            Text("This will change the speaker for ALL utterances currently assigned to \"\(utterance.speaker_name)\" in this conversation only.")
                                .appCaption()
                                .foregroundColor(.warning)
                                .padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
                
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
                    
                    Button("Save Changes") {
                        onSave(selectedSpeakerId, "", applyToAllUtterances)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(canSave ? Color.accent : Color.buttonSecondaryBackground)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(!canSave)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
        }
    }
    
    private var canSave: Bool {
        !selectedSpeakerId.isEmpty
    }
}

#Preview {
    ConversationDetailView(
        conversationId: "preview-id",
        speakerIDService: SpeakerIDService(),
        onConversationUpdated: nil
    )
} 
