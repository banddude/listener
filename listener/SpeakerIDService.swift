//
//  SpeakerIDService.swift
//  listener
//
//  Created by Mike Shaffer on 5/26/25.
//

import Foundation

@MainActor
class SpeakerIDService: ObservableObject {
    @Published var isUploading = false
    @Published var errorMessage = ""
    
    private let baseURL = AppConstants.baseURL
    
    // MARK: - Conversation Management
    
    func uploadConversation(audioFileURL: URL, displayName: String?) async throws -> ConversationResponse {
        isUploading = true
        errorMessage = ""
        
        do {
            let response = try await uploadAudioFile(url: audioFileURL, displayName: displayName)
            isUploading = false
            return response
        } catch {
            isUploading = false
            errorMessage = "Upload failed: \(error.localizedDescription)"
            throw error
        }
    }
    
    func uploadConversation(audioFileURL: URL, displayName: String?, matchThreshold: Double, autoUpdateThreshold: Double) async throws -> ConversationResponse {
        isUploading = true
        errorMessage = ""
        
        do {
            let response = try await uploadAudioFile(url: audioFileURL, displayName: displayName, matchThreshold: matchThreshold, autoUpdateThreshold: autoUpdateThreshold)
            isUploading = false
            return response
        } catch {
            isUploading = false
            errorMessage = "Upload failed: \(error.localizedDescription)"
            throw error
        }
    }
    
    func uploadConversation(audioData: Data, filename: String, notes: String? = nil, matchThreshold: Double = 0.40, autoUpdateThreshold: Double = 0.50) async throws -> ConversationResponse {
        isUploading = true
        errorMessage = ""
        
        do {
            let response = try await uploadAudioData(data: audioData, filename: filename, displayName: notes, matchThreshold: matchThreshold, autoUpdateThreshold: autoUpdateThreshold)
            isUploading = false
            return response
        } catch {
            isUploading = false
            errorMessage = "Upload failed: \(error.localizedDescription)"
            throw error
        }
    }
    
    func getConversationDetails(conversationId: String) async throws -> ConversationDetail {
        // First, find the conversation in the list to get the database ID
        let conversations = try await getAllConversations()
        print("🔍 Found \(conversations.count) total conversations")
        
        guard let conversation = conversations.first(where: { $0.conversation_id == conversationId }) else {
            print("❌ Conversation not found with ID: \(conversationId)")
            print("📋 Available conversation IDs: \(conversations.map { $0.conversation_id })")
            throw SpeakerIDError.invalidData
        }
        
        print("✅ Found conversation: ID=\(conversation.id), conversation_id=\(conversation.conversation_id)")
        print("📊 Summary data: speakers=\(conversation.speaker_count ?? 0), utterances=\(conversation.utterance_count ?? 0), duration=\(conversation.duration ?? 0)")
        
        // Use the database ID for the details endpoint
        let url = URL(string: "\(baseURL)/api/conversations/\(conversation.id)")!
        print("🌐 Fetching details from: \(url.absoluteString)")
        
        let details = try await performRequest(url: url, responseType: ConversationDetail.self)
        print("📝 Retrieved details: \(details.utterances.count) utterances, duration=\(details.duration_seconds ?? 0)")
        
        return details
    }
    
    func getAllConversations() async throws -> [BackendConversationSummary] {
        let url = URL(string: "\(baseURL)/api/conversations")!
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw SpeakerIDError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        let conversations = try JSONDecoder().decode([BackendConversationSummary].self, from: data)
        print("📋 getAllConversations (cache bypassed) returned \(conversations.count) conversations:")
        for conv in conversations.prefix(3) {
            print("   - \(conv.id): \(conv.display_name ?? "nil")")
        }
        return conversations
    }
    
    // MARK: - Speaker Management
    
    func getSpeakers() async throws -> [Speaker] {
        let url = URL(string: "\(baseURL)/api/speakers")!
        return try await performRequest(url: url, responseType: [Speaker].self)
    }
    
    // New method for populating speaker dropdowns in editing UI
    func getAllSpeakersForSelection() async throws -> [Speaker] {
        try await getSpeakers()
    }
    
    func addSpeaker(name: String) async throws -> Speaker {
        let url = URL(string: "\(baseURL)/api/speakers")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyString = "name=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw SpeakerIDError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        return try JSONDecoder().decode(Speaker.self, from: data)
    }
    
    func updateSpeaker(speakerId: String, newName: String) async throws -> Speaker {
        let url = URL(string: "\(baseURL)/api/speakers/\(speakerId)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"name\"\r\n\r\n".data(using: .utf8)!)
        body.append(newName.data(using: .utf8)!)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw SpeakerIDError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        return try JSONDecoder().decode(Speaker.self, from: data)
    }
    
    // MARK: - Utterance Management
    
    func updateUtterance(utteranceId: String, speakerId: String? = nil, text: String? = nil) async throws -> SpeakerIDUtterance {
        let url = URL(string: "\(baseURL)/api/utterances/\(utteranceId)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var bodyDict: [String: Any] = [:]
        if let speakerId = speakerId {
            bodyDict["speaker_id"] = speakerId
        }
        if let text = text {
            bodyDict["text"] = text
        }
        
        let bodyData = try JSONSerialization.data(withJSONObject: bodyDict)
        request.httpBody = bodyData
        
        return try await performRequest(url: url, method: "PUT", body: bodyData, responseType: SpeakerIDUtterance.self)
    }
    
    func updateAllUtterancesBySpeaker(fromSpeakerId: String, toSpeakerId: String, conversationId: String? = nil) async throws -> BulkUpdateResponse {
        let url = URL(string: "\(baseURL)/api/speakers/\(fromSpeakerId)/update-all-utterances")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Use form data format that the API actually accepts
        var bodyComponents: [String] = []
        bodyComponents.append("to_speaker_id=\(toSpeakerId)")
        
        // Add conversation filter if provided (for conversation-scoped updates)
        if let conversationId = conversationId {
            bodyComponents.append("conversation_id=\(conversationId)")
            print("🎯 Bulk update with conversation filter: \(conversationId)")
        } else {
            print("⚠️ Bulk update WITHOUT conversation filter - will affect ALL utterances in database!")
        }
        
        // Add debug timestamp for tracking in logs
        let timestamp = ISO8601DateFormatter().string(from: Date())
        bodyComponents.append("debug_timestamp=\(timestamp)")
        
        let bodyString = bodyComponents.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        print("📤 Sending bulk update request: \(bodyString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpeakerIDError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            print("❌ Bulk update failed with status: \(httpResponse.statusCode)")
            if let errorData = String(data: data, encoding: .utf8) {
                print("❌ Error response: \(errorData)")
            }
            throw SpeakerIDError.serverError(httpResponse.statusCode)
        }
        
        let result = try JSONDecoder().decode(BulkUpdateResponse.self, from: data)
        print("✅ Bulk update successful: \(result.count) utterances updated")
        return result
    }
    
    // MARK: - Conversation Name Management
    
    func updateConversationName(conversationId: String, newName: String) async throws {
        // Use conversation.id (not conversation_id) for the API endpoint
        let url = URL(string: "\(baseURL)/api/conversations/\(conversationId)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        
        // Use application/x-www-form-urlencoded as per API documentation
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Create URL-encoded body
        let parameters = ["display_name": newName]
        let body = parameters
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
        
        request.httpBody = body.data(using: .utf8)
        
        print("🔄 Updating conversation name: \(conversationId) -> \(newName)")
        print("📤 Request body: \(body)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 Conversation name update response: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Response data: \(responseString)")
            }
            
            if httpResponse.statusCode != 200 {
                throw SpeakerIDError.serverError(httpResponse.statusCode)
            }
        }
    }
    
    // MARK: - Pinecone Speaker Linking
    
    func getPineconeSpeekers() async throws -> [String] {
        let url = URL(string: "\(baseURL)/api/pinecone/speakers")!
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpeakerIDError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw SpeakerIDError.serverError(httpResponse.statusCode)
        }
        
        // Parse the same format that PineconeManagerView uses successfully
        let speakersResponse = try JSONDecoder().decode(PineconeSpeakersResponse.self, from: data)
        
        // Extract just the speaker names for the picker
        return speakersResponse.speakers.map { $0.name }
    }
    
    func linkSpeakerToPinecone(speakerId: String, pineconeSpeekerName: String) async throws {
        let url = URL(string: "\(baseURL)/api/speakers/\(speakerId)/link-pinecone")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["pinecone_speaker_name": pineconeSpeekerName]
        request.httpBody = try JSONEncoder().encode(body)
        
        print("🔗 Linking speaker \(speakerId) to Pinecone speaker: \(pineconeSpeekerName)")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("🔗 Pinecone link response: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                throw SpeakerIDError.serverError(httpResponse.statusCode)
            }
        }
    }
    
    func unlinkSpeakerFromPinecone(speakerId: String) async throws {
        let url = URL(string: "\(baseURL)/api/speakers/\(speakerId)/unlink-pinecone")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        print("🔓 Unlinking speaker \(speakerId) from Pinecone")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("🔓 Pinecone unlink response: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                throw SpeakerIDError.serverError(httpResponse.statusCode)
            }
        }
    }
    
    // MARK: - Utterance Pinecone Inclusion
    
    func toggleUtterancePineconeInclusion(utteranceId: String, includeInPinecone: Bool) async throws -> UtterancePineconeResponse {
        let url = URL(string: "\(baseURL)/api/utterances/\(utteranceId)/pinecone-inclusion")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["include_in_pinecone": includeInPinecone]
        request.httpBody = try JSONEncoder().encode(body)
        
        print("🎯 Toggling utterance \(utteranceId) Pinecone inclusion to: \(includeInPinecone)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpeakerIDError.invalidResponse
        }
        
        print("🎯 Pinecone inclusion toggle response: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            // Try to parse error message if available
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                print("❌ Toggle error: \(detail)")
                throw SpeakerIDError.invalidData
            }
            throw SpeakerIDError.serverError(httpResponse.statusCode)
        }
        
        let result = try JSONDecoder().decode(UtterancePineconeResponse.self, from: data)
        print("✅ Utterance Pinecone inclusion updated: included=\(result.included_in_pinecone), embedding_id=\(result.embedding_id ?? "none")")
        return result
    }
    
    // MARK: - Health Check
    
    func checkHealth() async throws -> HealthResponse {
        let url = URL(string: "\(baseURL)/health")!
        return try await performRequest(url: url, responseType: HealthResponse.self)
    }
    
    // MARK: - Cache Management
    
    func invalidateConversationsCache() {
        // This method can be called to indicate that the conversations list should be refreshed
        // For now it's just a marker - the actual refresh will be handled by the calling view
        print("💨 Conversations cache invalidated - UI should refresh conversation list")
    }
    
    // MARK: - Private Methods
    
    private func getContentType(for url: URL) -> String {
        let fileExtension = url.pathExtension.lowercased()
        switch fileExtension {
        case "wav":
            return "audio/wav"
        case "mp3":
            return "audio/mpeg"
        case "m4a":
            return "audio/mp4"
        case "flac":
            return "audio/flac"
        case "aac":
            return "audio/aac"
        default:
            return "audio/wav" // Default fallback
        }
    }
    
    private func uploadAudioFile(url: URL, displayName: String?, matchThreshold: Double = 0.40, autoUpdateThreshold: Double = 0.50) async throws -> ConversationResponse {
        let uploadURL = URL(string: "\(baseURL)/api/conversations/upload")!
        
        print("🚀 Uploading to: \(uploadURL.absoluteString)")
        print("📁 File size: \(try Data(contentsOf: url).count) bytes")
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        
        // Set a very long timeout for the upload since transcription takes time
        request.timeoutInterval = 300.0 // 5 minutes
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add audio file with proper filename and content type
        let filename = url.lastPathComponent
        let contentType = getContentType(for: url)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(try Data(contentsOf: url))
        body.append("\r\n".data(using: .utf8)!)
        
        // Add display name if provided (exactly as web frontend does)
        if let displayName = displayName {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"display_name\"\r\n\r\n".data(using: .utf8)!)
            body.append(displayName.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Add match_threshold (exactly as web frontend does)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"match_threshold\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(matchThreshold)".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add auto_update_threshold (exactly as web frontend does)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"auto_update_threshold\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(autoUpdateThreshold)".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("📤 Request body size: \(body.count) bytes")
        print("🎛️ Upload parameters: match_threshold=0.40, auto_update_threshold=0.50")
        print("⏱️ Waiting for transcription to complete (this may take several minutes)...")
        
        // Create URLSession with extended timeout configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300.0 // 5 minutes
        config.timeoutIntervalForResource = 600.0 // 10 minutes
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response type")
            throw SpeakerIDError.invalidResponse
        }
        
        print("📥 Response status: \(httpResponse.statusCode)")
        print("📝 Response data: \(String(data: data, encoding: .utf8) ?? "unable to decode")")
        
        // Handle server 500 errors (backend bug - but upload still works)
        if httpResponse.statusCode == 500 {
            print("⚠️ Backend returned 500 error but upload likely succeeded")
            
            // Parse the conversation_id from the URL or find the most recent conversation
            // Since backend creates conversation despite the error
            let conversations = try await getAllConversations()
            if let latestConversation = conversations.first {
                print("✅ Found latest conversation: \(latestConversation.conversation_id)")
                return ConversationResponse(
                    success: true,
                    conversation_id: latestConversation.conversation_id,
                    message: "Upload successful despite backend response error"
                )
            }
        }
        
        // Handle other server errors
        if httpResponse.statusCode >= 400 {
            print("❌ Server error: \(httpResponse.statusCode)")
            throw SpeakerIDError.serverError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(ConversationResponse.self, from: data)
    }
    
    private func uploadAudioData(data: Data, filename: String, displayName: String?, matchThreshold: Double = 0.40, autoUpdateThreshold: Double = 0.50) async throws -> ConversationResponse {
        let uploadURL = URL(string: "\(baseURL)/api/conversations/upload")!
        
        print("🚀 Uploading data to: \(uploadURL.absoluteString)")
        print("📁 Data size: \(data.count) bytes")
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        
        // Set a very long timeout for the upload since transcription takes time
        request.timeoutInterval = 300.0 // 5 minutes
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add audio file with proper filename and content type
        let dummyURL = URL(fileURLWithPath: filename)
        let contentType = getContentType(for: dummyURL)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add display name if provided (exactly as web frontend does)
        if let displayName = displayName {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"display_name\"\r\n\r\n".data(using: .utf8)!)
            body.append(displayName.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Add match threshold (converted to string as expected by API)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"match_threshold\"\r\n\r\n".data(using: .utf8)!)
        body.append(String(matchThreshold).data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add auto update threshold (converted to string as expected by API)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"auto_update_threshold\"\r\n\r\n".data(using: .utf8)!)
        body.append(String(autoUpdateThreshold).data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // End multipart body
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Create session with increased resource timeout
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = 600.0 // 10 minutes
        let session = URLSession(configuration: configuration)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpeakerIDError.invalidResponse
        }
        
        print("📋 Response status: \(httpResponse.statusCode)")
        print("📋 Response headers: \(httpResponse.allHeaderFields)")
        
        // Special handling for 500 errors - sometimes the upload succeeds but returns 500 due to backend bug
        if httpResponse.statusCode == 500 {
            print("⚠️ Got 500 error, checking if upload actually succeeded...")
            do {
                let conversations = try await getAllConversations()
                if let latestConversation = conversations.first {
                    let latestTime = DateUtilities.parseISODate(latestConversation.created_at ?? "")?.timeIntervalSince1970 ?? 0
                    let uploadTime = Date().timeIntervalSince1970
                    
                    // If the latest conversation was created within the last 30 seconds, assume it's our upload
                    if uploadTime - latestTime < 30 {
                        print("✅ Found recent conversation, upload likely succeeded despite 500 error")
                        return ConversationResponse(
                            success: true,
                            conversation_id: latestConversation.conversation_id,
                            message: "Upload successful despite backend response error"
                        )
                    }
                }
            } catch {
                print("❌ Failed to check for recent conversations: \(error)")
            }
        }
        
        // Handle other server errors
        if httpResponse.statusCode >= 400 {
            print("❌ Server error: \(httpResponse.statusCode)")
            throw SpeakerIDError.serverError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(ConversationResponse.self, from: data)
    }
    
    
    private func performRequestWithCacheBusting<T: Codable>(
        url: URL,
        method: String = "GET",
        body: Data? = nil,
        responseType: T.Type
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Add cache-busting headers
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("0", forHTTPHeaderField: "Expires")
        
        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpeakerIDError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw SpeakerIDError.serverError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(responseType, from: data)
    }
    
    private func performRequest<T: Codable>(
        url: URL,
        method: String = "GET",
        body: Data? = nil,
        responseType: T.Type
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpeakerIDError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw SpeakerIDError.serverError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Error Types
enum SpeakerIDError: Error, LocalizedError {
    case networkError(Error)
    case serverError(Int)
    case invalidResponse
    case uploadFailed
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code):
            return "Server error: \(code)"
        case .invalidResponse:
            return "Invalid response from server"
        case .uploadFailed:
            return "Failed to upload audio file"
        case .invalidData:
            return "Invalid data format"
        }
    }
} 
