import SwiftUI

enum TabIdentifier: Hashable {
    case recorder, conversations, speakers, upload, pinecone // Add all your tabs
}

class AppNavigationManager: ObservableObject {
    @Published var selectedTab: TabIdentifier = .recorder // Default tab
    @Published var conversationIdToView: String?

    func navigateToConversation(id: String) {
        conversationIdToView = id
        selectedTab = .conversations
        print("AppNavigationManager: Navigating to tab \(selectedTab) and conversationId \(conversationIdToView ?? "None")")
    }
    
    func clearConversationNavigation() {
        conversationIdToView = nil
    }
} 
