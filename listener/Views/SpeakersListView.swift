import SwiftUI
import Foundation
import AVFoundation

struct SpeakersListView: View {
    @State private var speakers: [Speaker] = []
    @State private var pineconeSpeakers: [PineconeSpeaker] = []
    let speakerIDService: SpeakerIDService
    
    @State private var isRefreshing = false
    @State private var isPineconeLoading = false
    @State private var showingAddSpeaker = false
    @State private var addEmbeddingItem: AddEmbeddingItem?
    @State private var newSpeakerName = ""
    @State private var errorMessage = ""
    
    struct AddEmbeddingItem: Identifiable {
        let id = UUID()
        let speakerName: String
    }
    
    var body: some View {
        AppScrollContainer(spacing: 20) {
            // Header
            HStack {
                Text("All Speakers (\(speakers.count + pineconeSpeakers.count))")
                    .appHeadline()
                
                Spacer()
                
                HStack(spacing: AppSpacing.small) {
                    // Refresh button
                    Button(action: {
                        refreshAllData()
                    }) {
                        Image(systemName: AppIcons.refresh)
                            .font(.title2)
                            .foregroundColor(.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(isRefreshing || isPineconeLoading)
                    
                    // Add speaker button
                    Button(action: {
                        showingAddSpeaker = true
                    }) {
                        Image(systemName: AppIcons.add)
                            .font(.title2)
                            .foregroundColor(.success)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.medium)
                
            // Unified Speaker List
            if speakers.isEmpty && pineconeSpeakers.isEmpty && !isRefreshing && !isPineconeLoading {
                AppEmptyState(
                    icon: AppIcons.noSpeakers,
                    title: "No speakers found",
                    subtitle: "Speakers will appear here after processing conversations"
                )
            } else {
                LazyVStack(spacing: 16) {
                    // Linked Speakers Section (conversation speakers that have Pinecone links)
                    let linkedSpeakers = speakers.filter { $0.pinecone_speaker_name != nil }
                    if !linkedSpeakers.isEmpty {
                        AppSectionHeader(
                            title: "Linked Speakers",
                            subtitle: "\(linkedSpeakers.count) speakers with voice training"
                        )
                        
                        ForEach(linkedSpeakers, id: \.id) { speaker in
                            // Find the matching Pinecone speaker
                            let matchingPineconeSpeaker = pineconeSpeakers.first { 
                                $0.name == speaker.pinecone_speaker_name 
                            }
                            
                            LinkedSpeakerCard(
                                conversationSpeaker: speaker,
                                pineconeSpeaker: matchingPineconeSpeaker,
                                speakerIDService: speakerIDService,
                                onTrainSpeaker: { speakerName in
                                    addEmbeddingItem = AddEmbeddingItem(speakerName: speakerName)
                                },
                                onSpeakerUpdated: {
                                    refreshSpeakers()
                                    refreshPineconeSpeakers()
                                },
                                onDeleteSpeaker: deletePineconeSpeaker,
                                onDeleteEmbedding: deletePineconeEmbedding
                            )
                        }
                    }
                    
                    // Unlinked Conversation Speakers Section
                    let unlinkedSpeakers = speakers.filter { $0.pinecone_speaker_name == nil }
                    if !unlinkedSpeakers.isEmpty {
                        AppSectionHeader(
                            title: "Conversation Speakers",
                            subtitle: "\(unlinkedSpeakers.count) speakers not yet trained"
                        )
                        
                        ForEach(unlinkedSpeakers, id: \.id) { speaker in
                            UnifiedSpeakerCard(
                                speaker: .conversation(speaker),
                                speakerIDService: speakerIDService,
                                onTrainSpeaker: { speakerName in
                                    addEmbeddingItem = AddEmbeddingItem(speakerName: speakerName)
                                },
                                onSpeakerUpdated: {
                                    refreshSpeakers()
                                },
                                onDeleteSpeaker: nil,
                                onDeleteEmbedding: nil
                            )
                        }
                    }
                    
                    // Unlinked Voice Samples Section (Pinecone speakers not linked to conversation speakers)
                    let unlinkedPineconeSpeakers = pineconeSpeakers.filter { pineconeSpeaker in
                        !speakers.contains { $0.pinecone_speaker_name == pineconeSpeaker.name }
                    }
                    if !unlinkedPineconeSpeakers.isEmpty {
                        AppSectionHeader(
                            title: "Voice Samples Only",
                            subtitle: "\(unlinkedPineconeSpeakers.count) training speakers without conversations"
                        )
                        
                        ForEach(unlinkedPineconeSpeakers) { speaker in
                            UnifiedSpeakerCard(
                                speaker: .pinecone(speaker),
                                speakerIDService: speakerIDService,
                                onTrainSpeaker: { speakerName in
                                    addEmbeddingItem = AddEmbeddingItem(speakerName: speakerName)
                                },
                                onSpeakerUpdated: {
                                    refreshPineconeSpeakers()
                                },
                                onDeleteSpeaker: deletePineconeSpeaker,
                                onDeleteEmbedding: deletePineconeEmbedding
                            )
                        }
                    }
                }
            }
            
            if isRefreshing || isPineconeLoading {
                AppLoadingState(message: "Loading speakers...")
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
        .sheet(item: $addEmbeddingItem) { item in
            // Check if this is a conversation speaker or Pinecone speaker
            if speakers.contains(where: { $0.name == item.speakerName }) {
                // Training from conversation speakers
                PineconeTrainSpeakerView(
                    speakerName: item.speakerName
                ) {
                    addEmbeddingItem = nil
                    refreshPineconeSpeakers()
                }
            } else {
                // Adding more samples to existing Pinecone speaker
                PineconeAddEmbeddingView(
                    speakerName: item.speakerName
                ) {
                    addEmbeddingItem = nil
                    refreshPineconeSpeakers()
                }
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

// Unified speaker type to handle both conversation and Pinecone speakers
enum UnifiedSpeaker: Identifiable {
    case conversation(Speaker)
    case pinecone(PineconeSpeaker)
    
    var id: String {
        switch self {
        case .conversation(let speaker):
            return "conv_\(speaker.id)"
        case .pinecone(let speaker):
            return "pine_\(speaker.name)"
        }
    }
    
    var name: String {
        switch self {
        case .conversation(let speaker):
            return speaker.name
        case .pinecone(let speaker):
            return speaker.name
        }
    }
}

struct LinkedSpeakerCard: View {
    let conversationSpeaker: Speaker
    let pineconeSpeaker: PineconeSpeaker?
    let speakerIDService: SpeakerIDService
    let onTrainSpeaker: (String) -> Void
    let onSpeakerUpdated: () -> Void
    let onDeleteSpeaker: ((String) -> Void)?
    let onDeleteEmbedding: ((String) -> Void)?
    
    @State private var showingDetails = false
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(conversationSpeaker.name)
                            .appHeadline()
                        
                        // Linked indicator
                        Image(systemName: "link.circle.fill")
                            .foregroundColor(.success)
                            .font(.caption)
                    }
                    
                    if let pineconeSpeekerName = conversationSpeaker.pinecone_speaker_name {
                        Text("linked to: \(pineconeSpeekerName)")
                            .appCaption()
                            .foregroundColor(.success)
                    }
                    
                    HStack(spacing: 12) {
                        if let utteranceCount = conversationSpeaker.utterance_count {
                            Text("\(utteranceCount) utterances")
                                .appCaption()
                        }
                        
                        if let totalDuration = conversationSpeaker.total_duration {
                            Text(DurationUtilities.formatDurationCompact(TimeInterval(totalDuration)))
                                .appCaption()
                        }
                        
                        if let pineconeSpeaker = pineconeSpeaker {
                            Text("\(pineconeSpeaker.embeddings.count) voice samples")
                                .appCaption()
                                .foregroundColor(.accent)
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: AppSpacing.small) {
                    // Train button for conversation speakers
                    if let utteranceCount = conversationSpeaker.utterance_count, utteranceCount > 0 {
                        Button(action: {
                            onTrainSpeaker(conversationSpeaker.name)
                        }) {
                            Image(systemName: "brain")
                                .font(.title2)
                                .foregroundColor(.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Add embedding for Pinecone speakers
                    if pineconeSpeaker != nil {
                        Button(action: {
                            onTrainSpeaker(conversationSpeaker.name)
                        }) {
                            Image(systemName: "plus.circle")
                                .font(.title2)
                                .foregroundColor(.success)
                        }
                        .buttonStyle(.plain)
                        
                        // Expand/collapse embeddings
                        if let pinecone = pineconeSpeaker, !pinecone.embeddings.isEmpty {
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
                        
                        // Delete speaker (only for Pinecone)
                        if let onDeleteSpeaker = onDeleteSpeaker, let pineconeSpeekerName = conversationSpeaker.pinecone_speaker_name {
                            Button(action: {
                                onDeleteSpeaker(pineconeSpeekerName)
                            }) {
                                Image(systemName: "trash")
                                    .font(.title2)
                                    .foregroundColor(.destructive)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Detail chevron for conversation speakers
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
            
            // Expandable embeddings list for Pinecone speakers
            if let pinecone = pineconeSpeaker, !pinecone.embeddings.isEmpty && isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Voice Samples:")
                        .appSubtitle()
                    
                    ForEach(pinecone.embeddings) { embedding in
                        HStack {
                            Text(embedding.id)
                                .appCaption()
                            
                            Spacer()
                            
                            if let onDeleteEmbedding = onDeleteEmbedding {
                                Button(action: {
                                    onDeleteEmbedding(embedding.id)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundColor(.destructive)
                                }
                                .buttonStyle(.plain)
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
        .background(Color.lightGrayBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetails = true
        }
        .sheet(isPresented: $showingDetails) {
            SpeakerDetailView(
                speaker: conversationSpeaker,
                speakerIDService: speakerIDService,
                onSpeakerUpdated: onSpeakerUpdated,
                onTrainSpeaker: onTrainSpeaker
            )
        }
    }
}

struct UnifiedSpeakerCard: View {
    let speaker: UnifiedSpeaker
    let speakerIDService: SpeakerIDService
    let onTrainSpeaker: (String) -> Void
    let onSpeakerUpdated: () -> Void
    let onDeleteSpeaker: ((String) -> Void)?
    let onDeleteEmbedding: ((String) -> Void)?
    
    @State private var showingDetails = false
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(speaker.name)
                            .appHeadline()
                        
                        // Type indicator
                        switch speaker {
                        case .conversation(let convSpeaker):
                            if convSpeaker.pinecone_speaker_name != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.success)
                                    .font(.caption)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondaryText)
                                    .font(.caption)
                            }
                        case .pinecone:
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.accent)
                                .font(.caption)
                        }
                    }
                    
                    // Speaker details
                    switch speaker {
                    case .conversation(let convSpeaker):
                        if let pineconeSpeekerName = convSpeaker.pinecone_speaker_name {
                            Text("linked to: \(pineconeSpeekerName)")
                                .appCaption()
                                .foregroundColor(.success)
                        }
                        
                        HStack(spacing: 12) {
                            if let utteranceCount = convSpeaker.utterance_count {
                                Text("\(utteranceCount) utterances")
                                    .appCaption()
                            }
                            
                            if let totalDuration = convSpeaker.total_duration {
                                Text(DurationUtilities.formatDurationCompact(TimeInterval(totalDuration)))
                                    .appCaption()
                            }
                        }
                        
                    case .pinecone(let pineSpeaker):
                        Text("\(pineSpeaker.embeddings.count) voice samples")
                            .appCaption()
                    }
                }
                
                Spacer()
                
                HStack(spacing: AppSpacing.small) {
                    // Inline actions based on speaker type
                    switch speaker {
                    case .conversation(let convSpeaker):
                        // Train button for conversation speakers
                        if let utteranceCount = convSpeaker.utterance_count, utteranceCount > 0 {
                            Button(action: {
                                onTrainSpeaker(convSpeaker.name)
                            }) {
                                Image(systemName: "brain")
                                    .font(.title2)
                                    .foregroundColor(.accent)
                            }
                            .buttonStyle(.plain)
                        }
                        
                    case .pinecone(let pineSpeaker):
                        // Add embedding for Pinecone speakers
                        Button(action: {
                            onTrainSpeaker(pineSpeaker.name)
                        }) {
                            Image(systemName: "plus.circle")
                                .font(.title2)
                                .foregroundColor(.success)
                        }
                        .buttonStyle(.plain)
                        
                        // Expand/collapse embeddings
                        if !pineSpeaker.embeddings.isEmpty {
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
                        
                        // Delete speaker (only for Pinecone)
                        if let onDeleteSpeaker = onDeleteSpeaker {
                            Button(action: {
                                onDeleteSpeaker(pineSpeaker.name)
                            }) {
                                Image(systemName: "trash")
                                    .font(.title2)
                                    .foregroundColor(.destructive)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Detail chevron for conversation speakers
                    if case .conversation = speaker {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                }
            }
            
            // Expandable embeddings list for Pinecone speakers
            if case .pinecone(let pineSpeaker) = speaker, !pineSpeaker.embeddings.isEmpty && isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Voice Samples:")
                        .appSubtitle()
                    
                    ForEach(pineSpeaker.embeddings) { embedding in
                        HStack {
                            Text(embedding.id)
                                .appCaption()
                            
                            Spacer()
                            
                            if let onDeleteEmbedding = onDeleteEmbedding {
                                Button(action: {
                                    onDeleteEmbedding(embedding.id)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundColor(.destructive)
                                }
                                .buttonStyle(.plain)
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
        .background(Color.lightGrayBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // Only show details for conversation speakers
            if case .conversation = speaker {
                showingDetails = true
            } else if case .pinecone(let pineSpeaker) = speaker, !pineSpeaker.embeddings.isEmpty {
                // For Pinecone speakers, toggle expansion
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }
        }
        .sheet(isPresented: $showingDetails) {
            if case .conversation(let convSpeaker) = speaker {
                SpeakerDetailView(
                    speaker: convSpeaker,
                    speakerIDService: speakerIDService,
                    onSpeakerUpdated: onSpeakerUpdated,
                    onTrainSpeaker: onTrainSpeaker
                )
            }
        }
    }
}

struct SpeakerCard: View {
    let speaker: Speaker
    let speakerIDService: SpeakerIDService
    let onTrainSpeaker: (String) -> Void
    let onSpeakerUpdated: () -> Void
    
    @State private var showingDetails = false
    
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
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
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
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetails = true
        }
        .sheet(isPresented: $showingDetails) {
            SpeakerDetailView(
                speaker: speaker,
                speakerIDService: speakerIDService,
                onSpeakerUpdated: onSpeakerUpdated,
                onTrainSpeaker: onTrainSpeaker
            )
        }
    }
}

struct SpeakerDetailView: View {
    let speaker: Speaker
    let speakerIDService: SpeakerIDService
    let onSpeakerUpdated: () -> Void
    let onTrainSpeaker: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
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
                    
                    // Actions
                    AppInfoCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Actions")
                                .appHeadline()
                            
                            // Edit Name
                            Button(action: {
                                editedName = speaker.name
                                showingEditName = true
                            }) {
                                HStack {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.accent)
                                    Text("Edit Name")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondaryText)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Divider()
                            
                            // Pinecone Link/Unlink
                            if isLinking {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("Updating Pinecone link...")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            } else if isLinkedToPinecone {
                                Button(action: {
                                    unlinkFromPinecone()
                                }) {
                                    HStack {
                                        Image(systemName: "link.slash")
                                            .foregroundColor(.destructive)
                                        VStack(alignment: .leading) {
                                            Text("Unlink from Pinecone")
                                                .foregroundColor(.primary)
                                            if let pineconeSpeekerName = speaker.pinecone_speaker_name {
                                                Text("Linked to: \(pineconeSpeekerName)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondaryText)
                                    }
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button(action: {
                                    loadPineconeSpeekersAndShowPicker()
                                }) {
                                    HStack {
                                        Image(systemName: "link")
                                            .foregroundColor(.accent)
                                        Text("Link to Pinecone")
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondaryText)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Divider()
                            
                            // Train Button
                            if let utteranceCount = speaker.utterance_count, utteranceCount > 0 {
                                Button(action: {
                                    onTrainSpeaker(speaker.name)
                                    dismiss()
                                }) {
                                    HStack {
                                        Image(systemName: "brain")
                                            .foregroundColor(.accent)
                                        Text("Train Voice Recognition")
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondaryText)
                                    }
                                }
                                .buttonStyle(.plain)
                            } else {
                                HStack {
                                    Image(systemName: "brain")
                                        .foregroundColor(.secondary)
                                    Text("Train Voice Recognition")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("No utterances")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
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
    @State private var showingDetails = false
    
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
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetails = true
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

struct PineconeTrainSpeakerView: View {
    let speakerName: String
    let onEmbeddingAdded: () -> Void
    
    @State private var selectedAudioURL: URL?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingDocumentPicker = false
    @State private var existingUtterances: [SpeakerIDUtterance] = []
    @State private var isLoadingUtterances = false
    @State private var toggleStates: [String: Bool] = [:]
    @State private var processingUtterances: Set<String> = []
    @State private var audioPlayer: AVPlayer?
    @State private var currentlyPlayingURL: String?
    
    private let speakerIDService = SpeakerIDService()
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "brain")
                        .foregroundColor(Color.accent)
                        .font(.title)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Train voice recognition for:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(speakerName)
                            .font(.headline)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            // Existing utterances section
            if isLoadingUtterances {
                Section(header: Text("Existing Voice Samples")) {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading existing utterances...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            } else if !existingUtterances.isEmpty {
                Section(header: 
                    HStack {
                        Text("Existing Voice Samples")
                        Spacer()
                        Text("Use for Training")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                ) {
                    ForEach(existingUtterances, id: \.id) { utterance in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(utterance.text)
                                    .font(.body)
                                    .lineLimit(2)
                                
                                Text(utterance.start_time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Play button
                            Button(action: {
                                playUtterance(utterance)
                            }) {
                                Image(systemName: currentlyPlayingURL == utterance.audio_url ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.accent)
                            }
                            .buttonStyle(.plain)
                            
                            if processingUtterances.contains(utterance.id) {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text(toggleStates[utterance.id] == true ? "Adding..." : "Removing...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Toggle("", isOn: Binding(
                                    get: { toggleStates[utterance.id] ?? utterance.included_in_pinecone },
                                    set: { newValue in
                                        toggleUtterance(utterance.id, include: newValue)
                                    }
                                ))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            Section(header: Text("Add New Voice Sample")) {
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
        .navigationTitle("Train Speaker")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onEmbeddingAdded()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Train") {
                    trainSpeaker()
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
        .onAppear {
            loadExistingUtterances()
        }
        .onDisappear {
            cleanupAudioPlayer()
        }
    }
    
    private func loadExistingUtterances() {
        isLoadingUtterances = true
        
        Task {
            do {
                // Get all conversations and find utterances for this speaker
                let conversations = try await speakerIDService.getAllConversations()
                var allUtterances: [SpeakerIDUtterance] = []
                
                // Get details for each conversation and collect utterances from this speaker
                for conversation in conversations {
                    do {
                        let detail = try await speakerIDService.getConversationDetails(conversationId: conversation.conversation_id)
                        let speakerUtterances = detail.utterances.filter { $0.speaker_name == speakerName }
                        allUtterances.append(contentsOf: speakerUtterances)
                    } catch {
                        print("Failed to load conversation \(conversation.conversation_id): \(error)")
                        continue
                    }
                }
                
                await MainActor.run {
                    self.existingUtterances = allUtterances
                    self.isLoadingUtterances = false
                    
                    // Initialize toggle states
                    for utterance in allUtterances {
                        self.toggleStates[utterance.id] = utterance.included_in_pinecone
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoadingUtterances = false
                    print("Failed to load utterances for speaker: \(error)")
                }
            }
        }
    }
    
    private func toggleUtterance(_ utteranceId: String, include: Bool) {
        // Update local state immediately for responsive UI
        toggleStates[utteranceId] = include
        processingUtterances.insert(utteranceId)
        
        Task {
            do {
                _ = try await speakerIDService.toggleUtterancePineconeInclusion(
                    utteranceId: utteranceId,
                    includeInPinecone: include
                )
                print("✅ Successfully toggled utterance \(utteranceId) to \(include)")
                
                _ = await MainActor.run {
                    self.processingUtterances.remove(utteranceId)
                }
            } catch {
                // Revert local state on error
                await MainActor.run {
                    self.toggleStates[utteranceId] = !include
                    self.processingUtterances.remove(utteranceId)
                    self.errorMessage = "Failed to update utterance: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func playUtterance(_ utterance: SpeakerIDUtterance) {
        if currentlyPlayingURL == utterance.audio_url {
            // Already playing this utterance, pause it
            cleanupAudioPlayer()
            currentlyPlayingURL = nil
            return
        }
        
        cleanupAudioPlayer()
        
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
    
    private func getFullAudioURL(_ urlString: String) -> String {
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return urlString
        }
        
        let baseURL = AppConstants.baseURL
        return baseURL + urlString
    }
    
    private func cleanupAudioPlayer() {
        audioPlayer?.pause()
        
        // Remove all notification observers
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: nil)
        
        audioPlayer = nil
    }
    
    private func trainSpeaker() {
        guard let audioURL = selectedAudioURL else { return }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                // Use the speakers endpoint which creates speaker if it doesn't exist
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
                    self.onEmbeddingAdded()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to train speaker: \(error.localizedDescription)"
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
