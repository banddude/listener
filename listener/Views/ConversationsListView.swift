import SwiftUI
import Foundation

struct ConversationsListView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    let conversations: [BackendConversationSummary]
    let speakerIDService: SpeakerIDService
    let onRefreshRequested: (() -> Void)?
    
    @State private var isRefreshing = false
    @State private var showingUploadView = false
    
    var body: some View {
        NavigationStack {
            AppScrollContainer(spacing: 20) {
                // Header with Upload and Refresh buttons
                HStack {
                    Text("Conversations (\(conversations.count))")
                        .appHeadline()
                    
                    Spacer()
                    
                    HStack(spacing: AppSpacing.small) {
                        // Upload button
                        Button(action: {
                            showingUploadView = true
                        }) {
                            Image(systemName: AppIcons.tabUpload)
                                .font(.title2)
                                .foregroundColor(.accent)
                        }
                        .buttonStyle(.plain)
                        
                        // Refresh button
                        if let refreshAction = (isRefreshing ? nil : refreshConversations) {
                            Button(action: refreshAction) {
                                Image(systemName: AppIcons.refresh)
                                    .font(.title2)
                                    .foregroundColor(.accent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.medium)
                
                // Conversations List
                if conversations.isEmpty {
                    AppEmptyState(
                        icon: AppIcons.noConversations,
                        title: "No conversations found",
                        subtitle: "Upload an audio file to get started"
                    )
                } else {
                    ForEach(conversations, id: \.id) { conversation in
                        NavigationLink(value: conversation.conversation_id) {
                            ConversationCard(conversation: conversation)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if isRefreshing {
                    AppLoadingState(message: "Loading...")
                }
            }
            .sheet(isPresented: $showingUploadView) {
                NavigationView {
                    UploadView(speakerIDService: speakerIDService)
                        .navigationTitle("Upload Audio")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingUploadView = false
                                }
                            }
                        }
                }
                .onDisappear {
                    // Refresh conversations when upload view is dismissed
                    onRefreshRequested?()
                }
            }
            .navigationTitle("Conversations")
            .navigationDestination(for: String.self) { conversationId in
                ConversationDetailView(
                    conversationId: conversationId,
                    speakerIDService: speakerIDService,
                    onConversationUpdated: onRefreshRequested
                )
                .onDisappear {
                    if navigationManager.conversationIdToView == conversationId {
                        navigationManager.clearConversationNavigation()
                    }
                }
            }
            .task(id: navigationManager.conversationIdToView) {
                if navigationManager.selectedTab == .conversations,
                   let conversationId = navigationManager.conversationIdToView {
                    print("ConversationsListView: Detected navigation intent to \(conversationId)")
                }
            }
        }
    }
    
    private func refreshConversations() {
        isRefreshing = true
        onRefreshRequested?()
        
        // Reset refreshing state after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isRefreshing = false
        }
    }
}

struct ConversationCard: View {
    let conversation: BackendConversationSummary
    
    private var createdDate: Date? {
        guard let createdAt = conversation.created_at else { return nil }
        return DateUtilities.parseISODate(createdAt)
    }
    
    private var formattedDuration: String {
        let duration = conversation.duration ?? 0
        return DurationUtilities.formatDuration(TimeInterval(duration))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.display_name ?? "Untitled Conversation")
                        .appHeadline()
                        .lineLimit(1)
                    
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text(formattedDuration)
                                .appCaption()
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "person.2")
                                .font(.caption)
                            Text("\(conversation.speaker_count ?? 0)")
                                .appCaption()
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "text.bubble")
                                .font(.caption)
                            Text("\(conversation.utterance_count ?? 0)")
                                .appCaption()
                        }
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if (conversation.utterance_count ?? 0) > 0 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.success)
                            .font(.title2)
                        Text("Processed")
                            .appCaption()
                            .foregroundColor(.success)
                    } else {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.warning)
                            .font(.title2)
                        Text("Processing")
                            .appCaption()
                            .foregroundColor(.warning)
                    }
                }
            }
            
            if let date = createdDate {
                Text(DateUtilities.formatConversationDate(date))
                    .appCaption()
                    .foregroundColor(.secondaryText)
            }
        }
        .padding()
        .background(Color.lightGrayBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
    }
}

#Preview {
    NavigationView {
        ConversationsListView(
            conversations: [
                BackendConversationSummary(
                    id: "1",
                    conversation_id: "conv_1",
                    created_at: "2025-05-26T12:00:00.000Z",
                    duration: 3_720, // 1 hour 2 minutes
                    display_name: "Team Meeting",
                    speaker_count: 3,
                    utterance_count: 25,
                    speakers: ["Alice", "Bob", "Charlie"]
                ),
                BackendConversationSummary(
                    id: "2",
                    conversation_id: "conv_2",
                    created_at: "2025-05-26T11:30:00.000Z",
                    duration: 125, // 2 minutes 5 seconds
                    display_name: "Quick Chat",
                    speaker_count: 2,
                    utterance_count: 8,
                    speakers: ["Alice", "Bob"]
                )
            ],
            speakerIDService: SpeakerIDService(),
            onRefreshRequested: nil
        )
    }
} 
