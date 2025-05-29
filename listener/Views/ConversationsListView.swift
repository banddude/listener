import SwiftUI
import Foundation

struct ConversationsListView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    let conversations: [BackendConversationSummary]
    let speakerIDService: SpeakerIDService
    let onRefreshRequested: (() -> Void)?
    
    @State private var hiddenConversations: Set<String> = []
    @State private var isRefreshing = false
    @State private var showingUploadView = false
    @State private var conversationToDelete: BackendConversationSummary?
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var navigationPath = NavigationPath()
    
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                buildHeader()
                buildMainContent()
            }
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showingUploadView) {
                NavigationView {
                    UploadView(speakerIDService: speakerIDService)
                        .navigationTitle("Upload Audio")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showingUploadView = false }
                            }
                        }
                }
                .onDisappear { onRefreshRequested?() }
            }
            .confirmationDialog(
                "Delete Conversation",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let conversation = conversationToDelete {
                        deleteConversation(conversation)
                    }
                }
                Button("Cancel", role: .cancel) {
                    conversationToDelete = nil
                }
            } message: {
                if let conversation = conversationToDelete {
                    Text("Are you sure you want to delete \"\(conversation.display_name ?? "Untitled Conversation")\"? This action cannot be undone.")
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
            .onChange(of: conversations) { _, newValue in
                // Clear hidden conversations when parent data refreshes (e.g., after manual refresh)
                hiddenConversations.removeAll()
                print("🔄 Cleared hidden conversations due to data refresh. Total conversations: \(newValue.count)")
            }
        }
    }
    
    @ViewBuilder
    private func buildHeader() -> some View {
        HStack {
            Text("Conversations (\(conversations.filter { !hiddenConversations.contains($0.id) }.count))")
                .appHeadline()
            Spacer()
            HStack(spacing: AppSpacing.small) {
                Button(action: { showingUploadView = true }) {
                    Image(systemName: AppIcons.tabUpload)
                        .font(.title2)
                        .foregroundColor(.accent)
                }
                .buttonStyle(.plain)
                
                if !isRefreshing {
                    Button(action: refreshConversations) {
                        Image(systemName: AppIcons.refresh)
                            .font(.title2)
                            .foregroundColor(.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, AppSpacing.small)
        .background(Color(.systemGroupedBackground))
    }
    
    @ViewBuilder
    private func buildMainContent() -> some View {
        let filteredConversations = conversations.filter { !hiddenConversations.contains($0.id) }
        
        if filteredConversations.isEmpty {
            Spacer()
            AppEmptyState(
                icon: AppIcons.noConversations,
                title: "No conversations found",
                subtitle: "Upload an audio file to get started"
            )
            Spacer()
        } else {
            List(filteredConversations, id: \.id) { conversation in
                Button(action: {
                    navigationPath.append(conversation.conversation_id)
                }) {
                    ConversationCard(conversation: conversation)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        conversationToDelete = conversation
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .listStyle(.plain)
            .background(Color(.systemGroupedBackground))
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
    
    private func deleteConversation(_ conversation: BackendConversationSummary) {
        let conversationId = conversation.id
        
        print("🗑️ Attempting to delete conversation:")
        print("   - Display name: \(conversation.display_name ?? "Untitled")")
        print("   - ID: \(conversation.id)")
        print("   - Conversation ID: \(conversationId)")
        print("   - URL: \(AppConstants.baseURL)/api/conversations/\(conversationId)")
        
        isDeleting = true
        
        Task {
            do {
                let url = URL(string: "\(AppConstants.baseURL)/api/conversations/\(conversationId)")!
                var request = URLRequest(url: url)
                request.httpMethod = "DELETE"
                
                print("🌐 Making DELETE request to: \(url)")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                print("📡 DELETE response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    // Parse successful deletion response
                    if let deletionResult = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let deletedS3Objects = deletionResult["deleted_s3_objects"] as? Int ?? 0
                        let deletedUtterances = deletionResult["deleted_utterances"] as? Int ?? 0
                        let deletedEmbeddings = deletionResult["deleted_pinecone_embeddings"] as? Int ?? 0
                        
                        print("✅ Successfully deleted conversation \(conversationId)")
                        print("   - S3 objects: \(deletedS3Objects)")
                        print("   - Utterances: \(deletedUtterances)")
                        print("   - Pinecone embeddings: \(deletedEmbeddings)")
                    }
                    
                    await MainActor.run {
                        self.isDeleting = false
                        self.conversationToDelete = nil
                        // Hide the conversation to maintain scroll position
                        self.hiddenConversations.insert(conversationId)
                        let remainingCount = self.conversations.filter { !self.hiddenConversations.contains($0.id) }.count
                        print("🎯 Hid conversation from list. Visible remaining: \(remainingCount)")
                    }
                } else if httpResponse.statusCode == 404 {
                    await MainActor.run {
                        self.isDeleting = false
                        self.conversationToDelete = nil
                        print("⚠️ Conversation not found (already deleted?)")
                        // Hide from local state anyway
                        self.hiddenConversations.insert(conversationId)
                        let remainingCount = self.conversations.filter { !self.hiddenConversations.contains($0.id) }.count
                        print("🎯 Hid conversation from list (404 case). Visible remaining: \(remainingCount)")
                    }
                } else {
                    let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("❌ DELETE failed with status \(httpResponse.statusCode): \(errorResponse)")
                    
                    await MainActor.run {
                        self.isDeleting = false
                        if httpResponse.statusCode == 500 && errorResponse.contains("foreign key constraint") {
                            print("💾 Database constraint error - backend needs to handle cascading deletes")
                        }
                    }
                    return // Don't throw, just handle gracefully
                }
            } catch {
                await MainActor.run {
                    self.isDeleting = false
                    print("❌ Error deleting conversation: \(error.localizedDescription)")
                    // Could show an error alert here if desired
                }
            }
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
