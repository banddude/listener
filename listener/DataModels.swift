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