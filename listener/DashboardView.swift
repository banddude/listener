import SwiftUI
import Foundation

struct DashboardView: View {
    @StateObject private var speakerIDService = SpeakerIDService()
    @State private var selectedTab = 0
    @State private var conversations: [BackendConversationSummary] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Simple Header
            HStack {
                Text("Dashboard")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            
            // Compact Tab Navigation
            HStack(spacing: 0) {
                SimpleTabButton(
                    title: "Conversations",
                    icon: "bubble.left.and.bubble.right",
                    isSelected: selectedTab == 0,
                    action: { selectedTab = 0 }
                )
                
                SimpleTabButton(
                    title: "Speakers",
                    icon: "person.2",
                    isSelected: selectedTab == 1,
                    action: { selectedTab = 1 }
                )
                
                SimpleTabButton(
                    title: "Upload",
                    icon: "icloud.and.arrow.up",
                    isSelected: selectedTab == 2,
                    action: { selectedTab = 2 }
                )
                
                SimpleTabButton(
                    title: "Pinecone",
                    icon: "magnifyingglass",
                    isSelected: selectedTab == 3,
                    action: { selectedTab = 3 }
                )
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Content Area
            if isLoading {
                VStack {
                    ProgressView()
                    Text("Loading...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Group {
                    switch selectedTab {
                    case 0:
                        ConversationsListView(
                            conversations: conversations,
                            speakerIDService: speakerIDService,
                            onRefreshRequested: {
                                loadData()
                            }
                        )
                    case 1:
                        SpeakersListView(speakerIDService: speakerIDService)
                    case 2:
                        UploadView(speakerIDService: speakerIDService)
                    case 3:
                        PineconeManagerView()
                    default:
                        PineconeManagerView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                async let conversationsData = speakerIDService.getAllConversations()
                
                let loadedConversations = try await conversationsData
                
                await MainActor.run {
                    self.conversations = loadedConversations
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load data: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

struct SimpleTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .blue : .gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected ? Color.blue.opacity(0.1) : Color.clear
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DashboardView()
} 