//
//  Transcribe.swift
//  listener
//
//  Created by Mike Shaffer on 5/23/25.
//

import Foundation

// MARK: - AssemblyAI Data Models
struct AssemblyAITranscriptionRequest: Codable {
    let audio_url: String
    let speaker_labels: Bool
    let speech_model: String?
    
    init(audioURL: String, speakerLabels: Bool = true, speechModel: String? = "best") {
        self.audio_url = audioURL
        self.speaker_labels = speakerLabels
        self.speech_model = speechModel
    }
}

struct AssemblyAITranscriptionResponse: Codable {
    let id: String
    let status: String
    let audio_url: String?
    let text: String?
    let utterances: [Utterance]?
    let error: String?
    
    struct Utterance: Codable {
        let start: Int
        let end: Int
        let text: String
        let speaker: String
        let confidence: Double
    }
}



// MARK: - AssemblyAI Service
@MainActor
class TranscriptionService: ObservableObject {
    @Published var isTranscribing = false
    @Published var errorMessage = ""
    
    private let assemblyAIAPIKey = "426a653f0bf147d59fe1784289909665" // Replace with your API key
    private let baseURL = "https://api.assemblyai.com/v2"
    
    func transcribeAudio(audioFileURL: URL) async throws -> [ConversationSegment] {
        isTranscribing = true
        errorMessage = ""
        
        do {
            // Step 1: Upload audio file to AssemblyAI
            let uploadedURL = try await uploadAudioFile(audioFileURL: audioFileURL)
            
            // Step 2: Submit transcription request
            let transcriptID = try await submitTranscriptionRequest(audioURL: uploadedURL)
            
            // Step 3: Poll for completion
            let result = try await pollForCompletion(transcriptID: transcriptID)
            
            // Step 4: Convert to conversation segments
            let segments = convertToConversationSegments(result: result)
            
            isTranscribing = false
            return segments
            
        } catch {
            isTranscribing = false
            errorMessage = "Transcription failed: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func uploadAudioFile(audioFileURL: URL) async throws -> String {
        let url = URL(string: "\(baseURL)/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(assemblyAIAPIKey, forHTTPHeaderField: "authorization")
        
        let audioData = try Data(contentsOf: audioFileURL)
        request.httpBody = audioData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw TranscriptionError.uploadFailed
        }
        
        struct UploadResponse: Codable {
            let upload_url: String
        }
        
        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        return uploadResponse.upload_url
    }
    
    private func submitTranscriptionRequest(audioURL: String) async throws -> String {
        let url = URL(string: "\(baseURL)/transcript")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(assemblyAIAPIKey, forHTTPHeaderField: "authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = AssemblyAITranscriptionRequest(audioURL: audioURL)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw TranscriptionError.requestFailed
        }
        
        let transcriptionResponse = try JSONDecoder().decode(AssemblyAITranscriptionResponse.self, from: data)
        return transcriptionResponse.id
    }
    
    private func pollForCompletion(transcriptID: String) async throws -> AssemblyAITranscriptionResponse {
        let url = URL(string: "\(baseURL)/transcript/\(transcriptID)")!
        var request = URLRequest(url: url)
        request.setValue(assemblyAIAPIKey, forHTTPHeaderField: "authorization")
        
        while true {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  200...299 ~= httpResponse.statusCode else {
                throw TranscriptionError.pollingFailed
            }
            
            let result = try JSONDecoder().decode(AssemblyAITranscriptionResponse.self, from: data)
            
            switch result.status {
            case "completed":
                return result
            case "error":
                throw TranscriptionError.transcriptionFailed(result.error ?? "Unknown error")
            case "processing", "queued":
                // Wait 2 seconds before polling again
                try await Task.sleep(nanoseconds: 2_000_000_000)
                continue
            default:
                throw TranscriptionError.unknownStatus(result.status)
            }
        }
    }
    
    private func convertToConversationSegments(result: AssemblyAITranscriptionResponse) -> [ConversationSegment] {
        guard let utterances = result.utterances else {
            // Fallback: create single segment from text
            if let text = result.text, !text.isEmpty {
                return [ConversationSegment(
                    timestamp: "00:00",
                    speaker: nil,
                    text: text
                )]
            }
            return []
        }
        
        return utterances.map { utterance in
            let timestamp = formatTimestamp(milliseconds: utterance.start)
            return ConversationSegment(
                timestamp: timestamp,
                speaker: utterance.speaker,
                text: utterance.text
            )
        }
    }
    
    private func formatTimestamp(milliseconds: Int) -> String {
        let totalSeconds = milliseconds / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Error Types
enum TranscriptionError: Error, LocalizedError {
    case uploadFailed
    case requestFailed
    case pollingFailed
    case transcriptionFailed(String)
    case unknownStatus(String)
    
    var errorDescription: String? {
        switch self {
        case .uploadFailed:
            return "Failed to upload audio file"
        case .requestFailed:
            return "Failed to submit transcription request"
        case .pollingFailed:
            return "Failed to check transcription status"
        case .transcriptionFailed(let error):
            return "Transcription failed: \(error)"
        case .unknownStatus(let status):
            return "Unknown transcription status: \(status)"
        }
    }
} 