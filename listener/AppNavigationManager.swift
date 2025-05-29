import SwiftUI

enum TabIdentifier: Hashable {
    case recorder, conversations, speakers, pinecone
}

class AppNavigationManager: ObservableObject {
    @Published var selectedTab: TabIdentifier = .recorder
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