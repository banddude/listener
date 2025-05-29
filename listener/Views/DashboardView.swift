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
                    let tabWidth = (geometry.size.width - AppSpacing.medium) / 4 // 4 tabs now
                    
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
                        title: "Shared",
                        iconName: AppIcons.tabSharedUploads,
                        isSelected: navigationManager.selectedTab == .sharedUploads,
                        width: tabWidth
                    ) { navigationManager.selectedTab = .sharedUploads }
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
                    case .sharedUploads:
                        SharedUploadsView()
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
        print("🔄 DashboardView: loadData() called - refreshing conversations")
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                async let conversationsData = speakerIDService.getAllConversations()
                
                let loadedConversations = try await conversationsData
                
                await MainActor.run {
                    print("✅ DashboardView: Loaded \(loadedConversations.count) conversations")
                    self.conversations = loadedConversations
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    print("❌ DashboardView: Failed to load conversations: \(error.localizedDescription)")
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
