import SwiftUI
import Foundation

struct ConversationsListView: View {
    let conversations: [BackendConversationSummary]
    let speakerIDService: SpeakerIDService
    
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Conversations")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Refresh") {
                    refreshConversations()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding()
            
            // Conversations List
            if conversations.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No conversations found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Upload an audio file to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(conversations, id: \.id) { conversation in
                        NavigationLink(destination: ConversationDetailView(
                            conversation: conversation,
                            speakerIDService: speakerIDService
                        )) {
                            ConversationRow(conversation: conversation)
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    await refreshConversationsAsync()
                }
            }
        }
    }
    
    private func refreshConversations() {
        Task {
            await refreshConversationsAsync()
        }
    }
    
    private func refreshConversationsAsync() async {
        isRefreshing = true
        // Parent view will handle refresh through loadData()
        try? await Task.sleep(nanoseconds: 500_000_000) // Brief delay for UX
        isRefreshing = false
    }
}

struct ConversationRow: View {
    let conversation: BackendConversationSummary
    
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
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill((conversation.utterance_count ?? 0) > 0 ? .green : .orange)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(conversation.display_name ?? "Untitled Conversation")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Stats
                HStack(spacing: 16) {
                    Label("\(conversation.duration ?? 0) sec", systemImage: "clock")
                    Label("\(conversation.speaker_count ?? 0) speakers", systemImage: "person.2")
                    Label("\(conversation.utterance_count ?? 0) utterances", systemImage: "text.bubble")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                // Date
                if let date = createdDate {
                    Text(dateFormatter.string(from: date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Processing status
            VStack(alignment: .trailing, spacing: 4) {
                if (conversation.utterance_count ?? 0) > 0 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Processed")
                        .font(.caption2)
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                    Text("Processing")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 8)
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
                    duration: 120,
                    display_name: "Team Meeting",
                    speaker_count: 3,
                    utterance_count: 25,
                    speakers: ["Alice", "Bob", "Charlie"]
                )
            ],
            speakerIDService: SpeakerIDService()
        )
    }
} 