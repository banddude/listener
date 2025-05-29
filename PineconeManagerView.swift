import SwiftUI
import Foundation

struct PineconeManagerView: View {
    @State private var speakers: [PineconeSpeaker] = []
    @State private var isLoading = false
    @State private var showingAddSpeaker = false
    @State private var addEmbeddingItem: AddEmbeddingItem?

    struct AddEmbeddingItem: Identifiable {
        let id = UUID()
        let speakerName: String
    }
} 