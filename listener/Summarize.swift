//
//  Summarize.swift
//  listener
//
//  Created by Mike Shaffer on 5/23/25.
//

import Foundation



// MARK: - GPT-4.1-mini Summarization Service
@MainActor
class SummarizationService: ObservableObject {
    @Published var isSummarizing = false
    @Published var errorMessage = ""
    
    private let openAIAPIKey = "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" // Replace with your API key
    private let baseURL = "https://api.openai.com/v1"
    
    func summarizeConversation(segments: [ConversationSegment]) async throws -> ConversationSummary {
        isSummarizing = true
        errorMessage = ""
        
        do {
            let transcription = segmentsToText(segments)
            let summary = try await generateSummary(transcription: transcription)
            
            isSummarizing = false
            return summary
            
        } catch {
            isSummarizing = false
            errorMessage = "Summarization failed: \(error.localizedDescription)"
            throw error
        }
    }
    
    func transcribeAndSummarize(audioFileURL: URL) async -> TranscriptionResult? {
        do {
            // Use AssemblyAI for transcription
            let transcriptionService = TranscriptionService()
            let segments = try await transcriptionService.transcribeAudio(audioFileURL: audioFileURL)
            
            // Use GPT-4.1-mini for summarization
            let summary = try await summarizeConversation(segments: segments)
            
            return TranscriptionResult(conversation: segments, summary: summary)
            
        } catch {
            errorMessage = "Failed to process audio: \(error.localizedDescription)"
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func segmentsToText(_ segments: [ConversationSegment]) -> String {
        return segments.map { segment in
            if let speaker = segment.speaker {
                return "\(speaker): \(segment.text)"
            } else {
                return segment.text
            }
        }.joined(separator: "\n")
    }
    
    private func generateSummary(transcription: String) async throws -> ConversationSummary {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let prompt = """
        Please analyze this conversation transcription and provide a detailed summary in the following JSON format:
        
        {
          "title": "Brief descriptive title for this conversation",
          "keyPoints": ["Key point 1", "Key point 2", "Key point 3"],
          "actionItems": ["Action item 1", "Action item 2"],
          "participants": ["Speaker 1", "Speaker 2"],
          "duration": "Estimated duration",
          "topics": ["Topic 1", "Topic 2", "Topic 3"]
        }
        
        Guidelines:
        - Create a concise but descriptive title
        - Extract 3-5 key points that capture the main discussion
        - Identify specific action items or tasks mentioned
        - List all speakers/participants mentioned
        - Estimate duration based on content length
        - Identify main topics or themes discussed
        
        Transcription:
        \(transcription)
        
        Please respond with ONLY the JSON object, no additional text.
        """
        
        let requestBody: [String: Any] = [
            "model": "gpt-4.1-mini",  // Using GPT-4.1-mini as requested
            "messages": [
                [
                    "role": "system",
                    "content": "You are a helpful assistant that analyzes conversations and creates structured summaries. Always respond with valid JSON only."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 1000,
            "temperature": 0.3,
            "response_format": ["type": "json_object"]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SummarizationError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw SummarizationError.invalidAPIKey
        } else if !(200...299).contains(httpResponse.statusCode) {
            throw SummarizationError.requestFailed(httpResponse.statusCode)
        }
        
        struct ChatResponse: Codable {
            let choices: [Choice]
            
            struct Choice: Codable {
                let message: Message
                
                struct Message: Codable {
                    let content: String
                }
            }
        }
        
        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let summaryJSON = chatResponse.choices.first?.message.content else {
            throw SummarizationError.noResponse
        }
        
        // Parse the JSON response
        guard let summaryData = summaryJSON.data(using: .utf8) else {
            throw SummarizationError.invalidSummary
        }
        
        do {
            return try JSONDecoder().decode(ConversationSummary.self, from: summaryData)
        } catch {
            print("Failed to decode summary JSON: \(summaryJSON)")
            throw SummarizationError.invalidSummary
        }
    }
}

// MARK: - Error Types
enum SummarizationError: Error, LocalizedError {
    case invalidResponse
    case invalidSummary
    case noResponse
    case invalidAPIKey
    case requestFailed(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .invalidSummary:
            return "Failed to parse summary JSON"
        case .noResponse:
            return "No response from OpenAI API"
        case .invalidAPIKey:
            return "Invalid OpenAI API key"
        case .requestFailed(let statusCode):
            return "OpenAI API request failed with status code: \(statusCode)"
        }
    }
} 