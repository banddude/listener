//
//  DataModels.swift
//  listener
//
//  Created by Mike Shaffer on 5/23/25.
//

import Foundation

// MARK: - Shared Data Models
struct ConversationSegment: Codable, Identifiable {
    let id = UUID()
    let timestamp: String
    let speaker: String?
    let text: String
    
    private enum CodingKeys: String, CodingKey {
        case timestamp, speaker, text
    }
}

struct ConversationSummary: Codable {
    let title: String
    let keyPoints: [String]
    let actionItems: [String]
    let participants: [String]
    let duration: String
    let topics: [String]
}

struct TranscriptionResult: Codable, Identifiable {
    let id = UUID()
    let conversation: [ConversationSegment]
    let summary: ConversationSummary
    
    private enum CodingKeys: String, CodingKey {
        case conversation, summary
    }
}

// MARK: - Speaker ID Server API Models

struct ConversationResponse: Codable {
    let success: Bool
    let conversation_id: String
    let message: String
}

struct SpeakerIDUtterance: Codable {
    let id: String
    let speaker_id: String
    let speaker_name: String
    let start_time: String
    let end_time: String
    let start_ms: Int
    let end_ms: Int
    let text: String
    let audio_url: String
    let included_in_pinecone: Bool
    let utterance_embedding_id: String?
}

struct ConversationDetail: Codable {
    let id: String
    let conversation_id: String
    let display_name: String?
    let date_processed: String?
    let duration_seconds: Int?
    let utterances: [SpeakerIDUtterance]
}

struct Speaker: Codable, Identifiable {
    let id: String
    let name: String
    let utterance_count: Int?
    let total_duration: Int?
    let pinecone_speaker_name: String?
    
    // For API responses that might not include counts
    init(id: String, name: String, utterance_count: Int? = nil, total_duration: Int? = nil, pinecone_speaker_name: String? = nil) {
        self.id = id
        self.name = name
        self.utterance_count = utterance_count
        self.total_duration = total_duration
        self.pinecone_speaker_name = pinecone_speaker_name
    }
}

struct HealthResponse: Codable {
    let status: String
    let message: String
}

struct BulkUpdateResponse: Codable {
    let count: Int
    let message: String?
}

struct UtterancePineconeResponse: Codable {
    let success: Bool
    let utterance_id: String
    let included_in_pinecone: Bool
    let embedding_id: String?
    let message: String
}

struct BackendConversationSummary: Codable, Identifiable {
    let id: String
    let conversation_id: String
    let created_at: String?
    let duration: Int?
    var display_name: String?
    let speaker_count: Int?
    let utterance_count: Int?
    let speakers: [String]?
}

// MARK: - Pinecone Models (shared between PineconeManagerView and SpeakerIDService)
struct PineconeEmbedding: Codable, Identifiable {
    let id: String
}

struct PineconeSpeaker: Codable, Identifiable {
    let id = UUID()
    let name: String
    let embeddings: [PineconeEmbedding]
    
    enum CodingKeys: String, CodingKey {
        case name, embeddings
    }
}

struct PineconeSpeakersResponse: Codable {
    let speakers: [PineconeSpeaker]
} 