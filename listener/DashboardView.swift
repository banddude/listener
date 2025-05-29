import SwiftUI
import Foundation

struct DashboardView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    @StateObject private var speakerIDService = SpeakerIDService()
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
            
            // Responsive Tab Navigation
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    let tabWidth = (geometry.size.width - 16) / 5 // 8pt margin on each side
                    
                    ResponsiveTabButton(
                        title: "Recorder",
                        icon: "record.circle",
                        isSelected: navigationManager.selectedTab == .recorder,
                        width: tabWidth,
                        action: { navigationManager.selectedTab = .recorder }
                    )
                    
                    ResponsiveTabButton(
                        title: "Conversations",
                        icon: "bubble.left.and.bubble.right",
                        isSelected: navigationManager.selectedTab == .conversations,
                        width: tabWidth,
                        action: { navigationManager.selectedTab = .conversations }
                    )
                    
                    ResponsiveTabButton(
                        title: "Speakers",
                        icon: "person.2",
                        isSelected: navigationManager.selectedTab == .speakers,
                        width: tabWidth,
                        action: { navigationManager.selectedTab = .speakers }
                    )
                    
                    ResponsiveTabButton(
                        title: "Upload",
                        icon: "icloud.and.arrow.up",
                        isSelected: navigationManager.selectedTab == .upload,
                        width: tabWidth,
                        action: { navigationManager.selectedTab = .upload }
                    )
                    
                    ResponsiveTabButton(
                        title: "Pinecone",
                        icon: "magnifyingglass",
                        isSelected: navigationManager.selectedTab == .pinecone,
                        width: tabWidth,
                        action: { navigationManager.selectedTab = .pinecone }
                    )
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 60)
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
                    switch navigationManager.selectedTab {
                    case .recorder:
                        ListenerView()
                    case .conversations:
                        ConversationsListView(
                            conversations: conversations,
                            speakerIDService: speakerIDService,
                            onRefreshRequested: {
                                loadData()
                            }
                        )
                    case .speakers:
                        SpeakersListView(speakerIDService: speakerIDService)
                    case .upload:
                        UploadView(speakerIDService: speakerIDService)
                    case .pinecone:
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

struct ResponsiveTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let width: CGFloat
    let action: () -> Void
    
    private var fontSize: Font {
        // Adjust font size based on available width and text length
        if width < 70 || title.count > 8 {
            return .caption2
        } else if width < 80 {
            return .caption
        } else {
            return .footnote
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: width < 70 ? 12 : 14))
                Text(title)
                    .font(fontSize)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundColor(isSelected ? .blue : .gray)
            .frame(width: width, height: 50)
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