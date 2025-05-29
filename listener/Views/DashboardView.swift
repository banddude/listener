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
                    .appTitle()
                Spacer()
            }
            .padding(AppSpacing.medium)
            
            // Responsive Tab Navigation
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    let tabWidth = (geometry.size.width - AppSpacing.medium) / 4 // 8pt margin on each side
                    
                    AppTabButton(
                        title: "Recorder",
                        iconName: AppIcons.tabRecorder,
                        isSelected: navigationManager.selectedTab == .recorder,
                        width: tabWidth
                    ) { navigationManager.selectedTab = .recorder }
                    
                    AppTabButton(
                        title: "Conversations",
                        iconName: AppIcons.tabConversations,
                        isSelected: navigationManager.selectedTab == .conversations,
                        width: tabWidth
                    ) { navigationManager.selectedTab = .conversations }
                    
                    AppTabButton(
                        title: "Speakers",
                        iconName: AppIcons.tabSpeakers,
                        isSelected: navigationManager.selectedTab == .speakers,
                        width: tabWidth
                    ) { navigationManager.selectedTab = .speakers }
                    
                    AppTabButton(
                        title: "Pinecone",
                        iconName: AppIcons.tabPinecone,
                        isSelected: navigationManager.selectedTab == .pinecone,
                        width: tabWidth
                    ) { navigationManager.selectedTab = .pinecone }
                }
                .padding(.horizontal, AppSpacing.small)
            }
            .frame(height: AppSpacing.tabBarHeight)
            .padding(.bottom, AppSpacing.small)
            
            // Content Area
            if isLoading {
                AppLoadingState(message: "Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Group {
                    switch navigationManager.selectedTab {
                    case .recorder:
                        ListenerView()
                    case .conversations:
                        ConversationsListView(
                            conversations: conversations,
                            speakerIDService: speakerIDService
                        ) {
                                loadData()
                        }
                    case .speakers:
                        SpeakersListView(speakerIDService: speakerIDService)
                    case .pinecone:
                        PineconeManagerView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Error Message
            if !errorMessage.isEmpty {
                AppErrorMessage(message: errorMessage)
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

#Preview {
    DashboardView()
} 
