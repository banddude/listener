//
//  TranscriptionDetailView.swift
//  listener
//
//  Created by Mike Shaffer on 5/23/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct TranscriptionDetailView: View {
    let recording: URL
    let transcriptionResult: TranscriptionResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            TabView {
                // Conversation Tab
                ConversationView(conversation: transcriptionResult.conversation)
                    .tabItem {
                        Image(systemName: "bubble.left.and.bubble.right")
                        Text("Conversation")
                    }
                
                // Summary Tab
                SummaryView(summary: transcriptionResult.summary)
                    .tabItem {
                        Image(systemName: "doc.text")
                        Text("Summary")
                    }
            }
            .navigationTitle(transcriptionResult.summary.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: transcriptionJSONText()) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
    
    private func transcriptionJSONText() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let jsonData = try encoder.encode(transcriptionResult)
            return String(data: jsonData, encoding: .utf8) ?? "Failed to encode transcription"
        } catch {
            return "Error encoding transcription: \(error.localizedDescription)"
        }
    }
}

struct ConversationView: View {
    let conversation: [ConversationSegment]
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(conversation) { segment in
                    ConversationBubble(segment: segment)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct ConversationBubble: View {
    let segment: ConversationSegment
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp
            Text(segment.timestamp)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 4) {
                // Speaker
                if let speaker = segment.speaker {
                    Text(speaker)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                // Text
                Text(segment.text)
                    .font(.body)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                    )
            }
            
            Spacer()
        }
    }
}

struct SummaryView: View {
    let summary: ConversationSummary
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Basic Info
                SummarySection(title: "Details", icon: "info.circle") {
                    InfoRow(label: "Duration", value: summary.duration)
                    InfoRow(label: "Participants", value: summary.participants.joined(separator: ", "))
                }
                
                // Key Points
                if !summary.keyPoints.isEmpty {
                    SummarySection(title: "Key Points", icon: "star") {
                        ForEach(summary.keyPoints, id: \.self) { point in
                            BulletPoint(text: point)
                        }
                    }
                }
                
                // Action Items
                if !summary.actionItems.isEmpty {
                    SummarySection(title: "Action Items", icon: "checkmark.circle") {
                        ForEach(summary.actionItems, id: \.self) { item in
                            BulletPoint(text: item, color: .orange)
                        }
                    }
                }
                
                // Topics
                if !summary.topics.isEmpty {
                    SummarySection(title: "Topics Discussed", icon: "tag") {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(summary.topics, id: \.self) { topic in
                                Text(topic)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct SummarySection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct BulletPoint: View {
    let text: String
    let color: Color
    
    init(text: String, color: Color = .blue) {
        self.text = text
        self.color = color
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

#Preview {
    TranscriptionDetailView(
        recording: URL(string: "file://test.wav")!,
        transcriptionResult: TranscriptionResult(
            conversation: [
                ConversationSegment(timestamp: "00:00", speaker: "Speaker 1", text: "Hello, how are you today?"),
                ConversationSegment(timestamp: "00:05", speaker: "Speaker 2", text: "I'm doing well, thank you. How about you?"),
                ConversationSegment(timestamp: "00:10", speaker: "Speaker 1", text: "Great! I wanted to discuss the project timeline.")
            ],
            summary: ConversationSummary(
                title: "Project Timeline Discussion",
                keyPoints: ["Discussed project deadlines", "Reviewed resource allocation", "Identified potential risks"],
                actionItems: ["Send updated timeline by Friday", "Schedule follow-up meeting"],
                participants: ["John", "Sarah"],
                duration: "5 minutes",
                topics: ["Project Management", "Timeline", "Resources"]
            )
        )
    )
} 