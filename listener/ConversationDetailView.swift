import SwiftUI
import Foundation
import AVFoundation

struct ConversationDetailView: View {
    let conversation: BackendConversationSummary
    let speakerIDService: SpeakerIDService
    
    @State private var conversationDetail: ConversationDetail?
    @State private var isLoading = true
    @State private var errorMessage = ""
    
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
                    speakerIDService: speakerIDService
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
        .navigationTitle(conversation.display_name ?? "Conversation")
        .navigationBarTitleDisplayMode(.large)
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
    let conversation: BackendConversationSummary
    let detail: ConversationDetail
    let speakerIDService: SpeakerIDService
    
    @State private var selectedSpeaker: String?
    @State private var audioPlayer: AVPlayer?
    @State private var currentlyPlayingURL: String?
    @State private var isPlayingFullConversation = false
    @State private var currentUtteranceIndex: Int = 0
    @State private var timeObserver: Any?
    
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
        Array(Set(detail.utterances.map { $0.speaker_name })).sorted()
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Full Conversation Audio Player
                if !detail.utterances.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Full Conversation")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Button(action: {
                                if isPlayingFullConversation {
                                    stopSequentialPlayback()
                                } else {
                                    startSequentialPlayback()
                                }
                            }) {
                                Image(systemName: isPlayingFullConversation ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if isPlayingFullConversation {
                            Text("Playing utterance \(currentUtteranceIndex + 1) of \(detail.utterances.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Header Info
                VStack(alignment: .leading, spacing: 8) {
                    if let date = createdDate {
                        Text(dateFormatter.string(from: date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Stats
                    HStack(spacing: 20) {
                        StatItem(
                            icon: "clock",
                            title: "Duration",
                            value: formatDuration(detail.duration_seconds ?? conversation.duration ?? 0)
                        )
                        
                        StatItem(
                            icon: "person.2",
                            title: "Speakers",
                            value: "\(uniqueSpeakers.count)"
                        )
                        
                        StatItem(
                            icon: "text.bubble",
                            title: "Utterances",
                            value: "\(detail.utterances.count)"
                        )
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
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
                                    action: { selectedSpeaker = nil }
                                )
                                
                                ForEach(uniqueSpeakers, id: \.self) { speaker in
                                    SpeakerFilterButton(
                                        title: speaker,
                                        isSelected: selectedSpeaker == speaker,
                                        action: { selectedSpeaker = speaker }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Utterances
                if detail.utterances.isEmpty {
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
                        ForEach(filteredUtterances.indices, id: \.self) { index in
                            let utterance = filteredUtterances[index]
                            let isCurrentlyPlaying = isPlayingFullConversation && 
                                currentUtteranceIndex < detail.utterances.count &&
                                detail.utterances[currentUtteranceIndex].id == utterance.id
                            
                            UtteranceRow(
                                utterance: utterance,
                                isPlaying: isCurrentlyPlaying,
                                onPlayTap: {
                                    playIndividualUtterance(utterance)
                                }
                            )
                        }
                    }
                }
            }
            .padding()
        }
        .onDisappear {
            cleanupAudioPlayer()
        }
    }
    
    private var filteredUtterances: [SpeakerIDUtterance] {
        if let selectedSpeaker = selectedSpeaker {
            return detail.utterances.filter { $0.speaker_name == selectedSpeaker }
        }
        return detail.utterances
    }
    
    private func startSequentialPlayback() {
        print("🎵 Starting sequential conversation playback")
        cleanupAudioPlayer()
        currentUtteranceIndex = 0
        isPlayingFullConversation = true
        
        guard !detail.utterances.isEmpty else {
            print("❌ No utterances to play")
            return
        }
        
        playCurrentUtterance()
    }
    
    private func playCurrentUtterance() {
        guard currentUtteranceIndex < detail.utterances.count else {
            print("✅ Sequential conversation playback completed")
            stopSequentialPlayback()
            return
        }
        
        let currentUtterance = detail.utterances[currentUtteranceIndex]
        print("🎵 Playing utterance [\(currentUtteranceIndex + 1)/\(detail.utterances.count)]: \(currentUtterance.speaker_name)")
        
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
        
        if currentUtteranceIndex < detail.utterances.count && isPlayingFullConversation {
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
}

struct StatItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
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
    let utterance: SpeakerIDUtterance
    let isPlaying: Bool
    let onPlayTap: () -> Void
    
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
            
            VStack(alignment: .leading, spacing: 4) {
                // Speaker name, time, and play button
                HStack {
                    Text(utterance.speaker_name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: onPlayTap) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title3)
                            .foregroundColor(isValidAudioURL ? .blue : .gray)
                    }
                    .disabled(!isValidAudioURL)
                    
                    Text(utterance.start_time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Utterance text
                Text(utterance.text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
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
            speakerIDService: SpeakerIDService()
        )
    }
} 