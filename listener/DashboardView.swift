import SwiftUI
import Foundation

struct DashboardView: View {
    @StateObject private var speakerIDService = SpeakerIDService()
    @State private var selectedTab = 0
    @State private var conversations: [BackendConversationSummary] = []
    @State private var speakers: [Speaker] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Modern Header
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "person.2.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Speaker ID Dashboard")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Manage conversations and speakers")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                // Modern Tab Navigation
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ModernTabButton(
                            title: "Conversations",
                            icon: "bubble.left.and.bubble.right",
                            isSelected: selectedTab == 0,
                            action: { selectedTab = 0 }
                        )
                        
                        ModernTabButton(
                            title: "Speakers",
                            icon: "person.2",
                            isSelected: selectedTab == 1,
                            action: { selectedTab = 1 }
                        )
                        
                        ModernTabButton(
                            title: "Upload",
                            icon: "icloud.and.arrow.up",
                            isSelected: selectedTab == 2,
                            action: { selectedTab = 2 }
                        )
                        
                        ModernTabButton(
                            title: "Pinecone",
                            icon: "magnifyingglass",
                            isSelected: selectedTab == 3,
                            action: { selectedTab = 3 }
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                
                // Content Area
                Group {
                    if isLoading {
                        VStack {
                            ProgressView()
                            Text("Loading...")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        TabView(selection: $selectedTab) {
                            ConversationsListView(
                                conversations: conversations,
                                speakerIDService: speakerIDService
                            )
                            .tag(0)
                            
                            SpeakersListView(
                                speakers: speakers,
                                speakerIDService: speakerIDService
                            )
                            .tag(1)
                            
                            UploadView(speakerIDService: speakerIDService)
                                .tag(2)
                            
                            PineconeManagerView(speakerIDService: speakerIDService)
                                .tag(3)
                        }
                        #if os(iOS)
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        #endif
                    }
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
                async let speakersData = speakerIDService.getSpeakers()
                
                let (loadedConversations, loadedSpeakers) = try await (conversationsData, speakersData)
                
                await MainActor.run {
                    self.conversations = loadedConversations
                    self.speakers = loadedSpeakers
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

struct TabButton: View {
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
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                isSelected ? Color.blue.opacity(0.1) : Color.clear
            )
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ModernTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .blue)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        Color.blue.opacity(0.1)
                    }
                }
            )
            .cornerRadius(12)
            .shadow(color: isSelected ? .blue.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    DashboardView()
} 