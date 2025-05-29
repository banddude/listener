import SwiftUI
import Foundation
import AVFoundation

struct ConversationDetailView: View {
    let conversation: BackendConversationSummary
    let speakerIDService: SpeakerIDService
    let onConversationUpdated: (() -> Void)?
    
    @State private var conversationDetail: ConversationDetail?
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var refreshTrigger = 0
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading conversation details...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let detail = conversationDetail {
                ConversationDetailContent(
                    conversation: conversation,
                    detail: detail,
                    speakerIDService: speakerIDService,
                    onConversationUpdated: onConversationUpdated,
                    onNeedsFullReload: {
                        loadConversationDetail()
                    }
                )
            } else {
                // Error state
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("Failed to load conversation")
                        .font(.headline)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button("Retry") {
                        loadConversationDetail()
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
            loadConversationDetail()
        }
    }
    
    private func loadConversationDetail() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let detail = try await speakerIDService.getConversationDetails(
                    conversationId: conversation.conversation_id
                )
                
                await MainActor.run {
                    self.conversationDetail = detail
                    self.isLoading = false
                    
                    // Debug: Print conversation details and utterance URLs
                    print("🎯 Loaded conversation with \(detail.utterances.count) utterances:")
                    print("   Duration from detail: \(detail.duration_seconds ?? -1)s")
                    print("   Duration from conversation: \(conversation.duration ?? -1)s")
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
}

struct ConversationDetailContent: View {
    @State var conversation: BackendConversationSummary
    let detail: ConversationDetail
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
    @State private var editedConversationName = ""
    @State private var cachedSpeakers: [Speaker] = []
    @State private var isLoadingSpeakers = false
    
    // Add refresh mechanism
    @State private var conversationDetail: ConversationDetail?
    @State private var refreshTrigger = 0
    @State private var isRefreshing = false
    
    @State private var isEditingText = false
    @State private var isEditingSpeaker = false
    @State private var editedText = ""
    @State private var selectedSpeakerId = ""
    @State private var newSpeakerName = ""
    @State private var showingSpeakerPicker = false
    @State private var applyToAllUtterances = false
    @State private var isSavingEdit = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    private var createdDate: Date? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let createdAt = conversation.created_at else { return nil }
        return isoFormatter.date(from: createdAt)
    }
    
    private var uniqueSpeakers: [String] {
        Array(Set(currentDetail.utterances.map { $0.speaker_name })).sorted()
    }
    
    private var currentDetail: ConversationDetail {
        return conversationDetail ?? detail
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Refresh indicator
                if isRefreshing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Updating conversation...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Conversation Title Header with Play Button
                VStack(alignment: .leading, spacing: 12) {
                    // Title with edit functionality
                    HStack {
                        if isEditingConversationName {
                            TextField("Conversation name", text: $editedConversationName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onSubmit {
                                    saveConversationName()
                                }
                        } else {
                            Text(conversation.display_name ?? "Untitled Conversation")
                                .font(.title2)
                                .fontWeight(.bold)
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
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Date and play button row
                    HStack {
                        if let date = createdDate {
                            Text(dateFormatter.string(from: date))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(20)
                            }
                        }
                    }
                    
                    if isPlayingFullConversation {
                        Text("Playing utterance \(currentUtteranceIndex + 1) of \(selectedSpeaker != nil ? filteredUtterances.count : currentDetail.utterances.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.08))
                .cornerRadius(16)
                
                // Stats Card
                VStack(spacing: 12) {
                    HStack(spacing: 0) {
                        StatItem(
                            icon: "clock",
                            title: "Duration",
                            value: formatDuration(currentDetail.duration_seconds ?? conversation.duration ?? 0)
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
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(16)
                
                // Speaker Filter
                if !uniqueSpeakers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Filter by Speaker")
                            .font(.headline)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                SpeakerFilterButton(
                                    title: "All",
                                    isSelected: selectedSpeaker == nil,
                                    action: { 
                                        selectedSpeaker = nil 
                                    }
                                )
                                
                                ForEach(uniqueSpeakers, id: \.self) { speaker in
                                    SpeakerFilterButton(
                                        title: speaker,
                                        isSelected: selectedSpeaker == speaker,
                                        action: { 
                                            selectedSpeaker = speaker 
                                        }
                                    )
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
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("This conversation hasn't been processed yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredUtterances, id: \.id) { utterance in
                            let isCurrentlyPlaying = (isPlayingFullConversation && currentlyPlayingURL == utterance.audio_url) ||
                                                    (!isPlayingFullConversation && currentlyPlayingURL == utterance.audio_url)
                            
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
            .padding()
        }
        .onDisappear {
            cleanupAudioPlayer()
        }
        .onAppear {
            preloadSpeakers()
            conversationDetail = detail
        }
        .onChange(of: refreshTrigger) { oldValue, newValue in
            // When refresh trigger changes (after reload), also refresh speakers cache if needed
            if cachedSpeakers.isEmpty {
                preloadSpeakers()
            }
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
        print("🚨 DEBUG: playIndividualUtterance CALLED! Speaker: \(utterance.speaker_name)")
        print("🎯 DEBUG: playIndividualUtterance called for: \(utterance.speaker_name)")
        print("🎯 DEBUG: Current currentlyPlayingURL: \(currentlyPlayingURL ?? "nil")")
        print("🎯 DEBUG: Utterance audio_url: \(utterance.audio_url)")
        print("🎯 DEBUG: isPlayingFullConversation: \(isPlayingFullConversation)")
        
        if currentlyPlayingURL == utterance.audio_url && !isPlayingFullConversation {
            // Already playing this individual utterance, pause it
            print("🎯 DEBUG: Pausing currently playing individual utterance")
            cleanupAudioPlayer()
            currentlyPlayingURL = nil
            return
        }
        
        // Stop any current playback (full conversation or individual)
        print("🎯 DEBUG: Stopping any current playback and starting individual utterance")
        cleanupAudioPlayer()
        isPlayingFullConversation = false
        
        let fullURL = getFullAudioURL(utterance.audio_url)
        print("🎯 DEBUG: Full audio URL: \(fullURL)")
        
        guard let audioURL = URL(string: fullURL), audioURL.scheme != nil else {
            print("❌ DEBUG: Invalid audio URL for individual playback: \(fullURL)")
            return
        }
        
        // Set the currently playing URL immediately for UI feedback
        currentlyPlayingURL = utterance.audio_url
        print("🎯 DEBUG: Set currentlyPlayingURL to: \(currentlyPlayingURL ?? "nil")")
        print("🎯 Starting individual utterance playback: \(utterance.speaker_name)")
        
        let playerItem = AVPlayerItem(url: audioURL)
        audioPlayer = AVPlayer(playerItem: playerItem)
        print("🎯 DEBUG: Created AVPlayer and AVPlayerItem")
        
        // Add completion observer
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            DispatchQueue.main.async {
                print("✅ DEBUG: Individual audio playback completed")
                self.currentlyPlayingURL = nil
            }
        }
        
        // Add error observer
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { notification in
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                print("❌ DEBUG: Individual audio playback error: \(error)")
            }
            DispatchQueue.main.async {
                self.currentlyPlayingURL = nil
            }
        }
        
        audioPlayer?.play()
        print("🎵 DEBUG: Called audioPlayer.play() for individual audio playback")
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
        currentlyPlayingURL = nil  // Reset the playing state for UI updates
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            return "\(minutes)m \(remainingSeconds)s"
        } else {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            return "\(hours)h \(minutes)m"
        }
    }
    
    private func getFullAudioURL(_ urlString: String) -> String {
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return urlString
        }
        
        let baseURL = "https://speaker-id-server-production.up.railway.app"
        return baseURL + urlString
    }
    
    private func startEditingConversationName() {
        isEditingConversationName = true
        editedConversationName = conversation.display_name ?? ""
    }
    
    private func saveConversationName() {
        let newName = editedConversationName
        
        // Don't dismiss editing mode immediately - wait for update to complete
        if !newName.isEmpty {
            Task {
                do {
                    // Call the actual API to save the name
                    try await speakerIDService.updateConversationName(
                        conversationId: conversation.id, 
                        newName: newName
                    )
                    print("✅ Conversation name successfully updated to: \(newName)")
                    
                    // Update the local conversation object for immediate UI responsiveness
                    await MainActor.run {
                        self.conversation = BackendConversationSummary(
                            id: conversation.id,
                            conversation_id: conversation.conversation_id,
                            created_at: conversation.created_at,
                            duration: conversation.duration,
                            display_name: newName,
                            speaker_count: conversation.speaker_count,
                            utterance_count: conversation.utterance_count,
                            speakers: conversation.speakers
                        )
                    }
                    
                    // Small delay to ensure UI updates properly
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                    
                    await MainActor.run {
                        // Dismiss edit mode after update completes
                        isEditingConversationName = false
                        print("✅ Conversation name edit completed and UI updated")
                        
                        // Force UI refresh by incrementing refresh trigger
                        refreshTrigger += 1
                        
                        // Cache invalidation will happen when user navigates back naturally
                        speakerIDService.invalidateConversationsCache()
                        
                        // Call onConversationUpdated with a delay to refresh parent list
                        // without interfering with current editing session
                        Task {
                            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                            await MainActor.run {
                                onConversationUpdated?()
                                print("✅ Triggered parent conversations list refresh")
                            }
                        }
                    }
                } catch {
                    print("❌ Error updating conversation name: \(error.localizedDescription)")
                    // Revert to original name on error and dismiss edit mode
                    await MainActor.run {
                        self.editedConversationName = conversation.display_name ?? ""
                        self.isEditingConversationName = false
                    }
                }
            }
        } else {
            // Empty name, just dismiss
            isEditingConversationName = false
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
    
    private func refreshConversationDetail() {
        guard !isRefreshing else { 
            print("🔄 Refresh already in progress, skipping duplicate request")
            return 
        }
        
        isRefreshing = true
        Task {
            do {
                let updatedDetail = try await speakerIDService.getConversationDetails(
                    conversationId: conversation.conversation_id
                )
                await MainActor.run {
                    self.conversationDetail = updatedDetail
                    self.refreshTrigger += 1
                    self.isRefreshing = false
                    print("✅ Conversation detail refreshed with \(updatedDetail.utterances.count) utterances")
                }
            } catch {
                await MainActor.run {
                    self.isRefreshing = false
                }
                print("⚠️ Failed to refresh conversation detail: \(error.localizedDescription)")
            }
        }
    }
    
    private func refreshConversationDetailSync() async {
        guard !isRefreshing else { 
            print("🔄 Refresh already in progress, waiting for it to complete")
            // Wait for current refresh to complete
            while isRefreshing {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            return 
        }
        
        await MainActor.run {
            isRefreshing = true
        }
        
        // Preserve the current speaker filter selection
        let currentSelectedSpeaker = selectedSpeaker
        
        do {
            let updatedDetail = try await speakerIDService.getConversationDetails(
                conversationId: conversation.conversation_id
            )
            await MainActor.run {
                print("🔄 Applying refreshed conversation detail with \(updatedDetail.utterances.count) utterances")
                self.conversationDetail = updatedDetail
                self.refreshTrigger += 1
                
                // Restore the speaker filter if it's still valid
                if let previousSelection = currentSelectedSpeaker {
                    let updatedSpeakers = Array(Set(updatedDetail.utterances.map { $0.speaker_name }))
                    if updatedSpeakers.contains(previousSelection) {
                        self.selectedSpeaker = previousSelection
                        print("🎯 Restored speaker filter: \(previousSelection)")
                    } else {
                        print("⚠️ Previous speaker filter '\(previousSelection)' no longer exists, clearing filter")
                    }
                }
                
                self.isRefreshing = false
                print("✅ Conversation detail refreshed and UI updated")
                
                // Force SwiftUI to re-render by updating a state variable
                self.refreshTrigger += 1
            }
        } catch {
            await MainActor.run {
                self.isRefreshing = false
                print("⚠️ Failed to refresh conversation detail: \(error.localizedDescription)")
            }
        }
    }
}

struct StatItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SpeakerFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? Color.blue : Color.gray.opacity(0.2)
                )
                .foregroundColor(isSelected ? .white : .primary)
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
    
    // Access to the SpeakerIDService through environment
    @EnvironmentObject private var speakerIDService: SpeakerIDService
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
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
        
        let baseURL = "https://speaker-id-server-production.up.railway.app"
        return baseURL + urlString
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Speaker Avatar
            Circle()
                .fill(isPlaying ? Color.blue : Color.blue.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(utterance.speaker_name.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isPlaying ? .white : .blue)
                )
            
            VStack(alignment: .leading, spacing: 8) {
                // Speaker name row with edit functionality
                HStack {
                    Text(utterance.speaker_name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    // Pinecone inclusion status badge - MUCH MORE PROMINENT
                    HStack(spacing: 6) {
                        Image(systemName: utterance.included_in_pinecone ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(utterance.included_in_pinecone ? .green : .orange)
                        
                        Text("Pinecone")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(utterance.included_in_pinecone ? .green : .orange)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(utterance.included_in_pinecone ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(utterance.included_in_pinecone ? Color.green : Color.orange, lineWidth: 1)
                    )
                    .cornerRadius(12)
                    
                    Button(action: {
                        startEditingSpeaker()
                    }) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.blue)
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
                            .font(.title3)
                            .foregroundColor(isValidAudioURL ? .blue : .gray)
                    }
                    .buttonStyle(.plain)
                    .allowsHitTesting(true)
                    .contentShape(Circle())
                    // .disabled(!isValidAudioURL) // TEMPORARILY DISABLED FOR DEBUG
                    
                    Text(utterance.start_time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Utterance text with edit functionality
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if isEditingText {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Utterance text", text: $editedText, axis: .vertical)
                                    .font(.body)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .lineLimit(3...10)
                                
                                HStack {
                                    Button("Cancel") {
                                        cancelTextEdit()
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Button("Save") {
                                        saveUtteranceText()
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                }
                            }
                        } else {
                            Text(utterance.text)
                                .font(.body)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        if !isEditingText {
                            Spacer()
                            
                            Button(action: {
                                startEditingText()
                            }) {
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                // Show audio URL status if invalid
                if !isValidAudioURL {
                    Text("⚠️ Audio not available")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(isPlaying ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isPlaying ? Color.blue : Color.clear, lineWidth: 2)
        )
        .allowsHitTesting(true)
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
                            .background(Color.gray.opacity(0.1))
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
                                    Circle()
                                        .fill(Color.blue.opacity(0.2))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Text(String(speaker.name.prefix(1)).uppercased())
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.blue)
                                        )
                                    
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
                                            .foregroundColor(.blue)
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
                            .font(.subheadline)
                        
                        if applyToAllUtterances {
                            Text("This will change the speaker for ALL utterances currently assigned to \"\(utterance.speaker_name)\" in this conversation only.")
                                .font(.caption)
                                .foregroundColor(.orange)
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
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                    
                    Button("Save Changes") {
                        onSave(selectedSpeakerId, "", applyToAllUtterances)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(canSave ? Color.blue : Color.gray.opacity(0.3))
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
        return !selectedSpeakerId.isEmpty
    }
}

#Preview {
    NavigationView {
        ConversationDetailView(
            conversation: BackendConversationSummary(
                id: "1",
                conversation_id: "conv_1",
                created_at: "2025-05-26T12:00:00.000Z",
                duration: 120,
                display_name: "Team Meeting",
                speaker_count: 2,
                utterance_count: 5,
                speakers: ["Alice", "Bob"]
            ),
            speakerIDService: SpeakerIDService(),
            onConversationUpdated: nil
        )
    }
} 



