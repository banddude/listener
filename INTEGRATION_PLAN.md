# Speaker ID Server Integration Plan

## Overview

**Objective:** Migrate the current iOS "Listener" app from local audio transcription to leverage the existing Speaker ID Server backend for advanced speaker identification, conversation management, and web dashboard integration.

**Current State:** The iOS app records audio locally, transcribes using AssemblyAI API directly, and stores everything on the device.

**Target State:** The iOS app uploads recordings to the Speaker ID Server, which handles speaker identification, transcription with speaker labels, and syncs data to a web dashboard.

---

## 🎯 Simple Integration Strategy

### Phase 1: Backend Upload (Days 1-2)
- Replace local transcription with backend upload
- Maintain existing UI while switching data sources

### Phase 2: Speaker Features (Days 3-4)
- Add speaker management capabilities
- Integrate real-time speaker identification

### Phase 3: Dashboard Sync (Day 5)
- Enable web dashboard access
- Add conversation management features

---

## 📋 Detailed Implementation Plan

### Phase 1: Backend Upload Integration

#### 1.1 Create API Service Layer
**File:** `listener/SpeakerIDService.swift`

```swift
import Foundation

class SpeakerIDService: ObservableObject {
    private let baseURL = "https://speaker-id-server-production.up.railway.app"
    
    func uploadConversation(audioFileURL: URL, displayName: String?) async throws -> ConversationResponse {
        // POST /api/conversations/upload
    }
    
    func getConversationDetails(conversationId: String) async throws -> ConversationDetail {
        // GET /api/conversations/{conversation_id}
    }
}
```

#### 1.2 Update Data Models
**Modify:** `listener/DataModels.swift`

```swift
// Add new models to match backend API
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
}

struct ConversationDetail: Codable {
    let id: String
    let conversation_id: String
    let display_name: String?
    let utterances: [SpeakerIDUtterance]
}
```

#### 1.3 Replace Transcription Service
**Modify:** `listener/ContentView.swift`

```swift
// Replace transcribeRecording function
private func transcribeRecording(_ recording: URL) {
    currentlyTranscribing = recording
    selectedRecording = recording
    
    Task {
        do {
            let response = try await speakerIDService.uploadConversation(
                audioFileURL: recording,
                displayName: nil
            )
            
            let details = try await speakerIDService.getConversationDetails(
                conversationId: response.conversation_id
            )
            
            await MainActor.run {
                currentlyTranscribing = nil
                transcribedRecordings.insert(recording)
                // Convert backend response to existing format
                let result = convertBackendToLocal(details)
                savedTranscriptions[recording] = result
                selectedTranscriptionResult = result
            }
        } catch {
            await MainActor.run {
                currentlyTranscribing = nil
                errorMessage = "Upload failed: \(error.localizedDescription)"
            }
        }
    }
}
```

### Phase 2: Speaker Management Integration

#### 2.1 Add Speaker Management Service
**Extend:** `listener/SpeakerIDService.swift`

```swift
extension SpeakerIDService {
    func getSpeakers() async throws -> [Speaker] {
        // GET /api/speakers
    }
    
    func addSpeaker(name: String) async throws -> Speaker {
        // POST /api/speakers
    }
    
    func updateSpeaker(id: String, name: String) async throws -> Speaker {
        // PUT /api/speakers/{speaker_id}
    }
    
    func addPineconeSpeaker(name: String, audioFile: URL) async throws -> PineconeResponse {
        // POST /api/pinecone/speakers
    }
}
```

#### 2.2 Create Speaker Management View
**File:** `listener/SpeakerManagementView.swift`

```swift
struct SpeakerManagementView: View {
    @StateObject private var speakerService = SpeakerIDService()
    @State private var speakers: [Speaker] = []
    
    var body: some View {
        NavigationView {
            List {
                ForEach(speakers) { speaker in
                    SpeakerRow(speaker: speaker)
                }
            }
            .navigationTitle("Speakers")
            .toolbar {
                Button("Add Speaker") {
                    // Show add speaker sheet
                }
            }
        }
    }
}
```

#### 2.3 Update Main UI
**Modify:** `listener/ContentView.swift`

```swift
// Add navigation to speaker management
NavigationView {
    VStack {
        // Existing content...
        
        Button("Manage Speakers") {
            showingSpeakerManagement = true
        }
    }
    .sheet(isPresented: $showingSpeakerManagement) {
        SpeakerManagementView()
    }
}
```

### Phase 3: Dashboard Integration

#### 3.1 Add Conversation List from Backend
**File:** `listener/ConversationListView.swift`

```swift
struct ConversationListView: View {
    @StateObject private var speakerService = SpeakerIDService()
    @State private var conversations: [ConversationSummary] = []
    
    var body: some View {
        NavigationView {
            List(conversations) { conversation in
                ConversationRowView(conversation: conversation)
            }
            .navigationTitle("All Conversations")
            .onAppear {
                loadConversations()
            }
        }
    }
    
    private func loadConversations() {
        Task {
            do {
                conversations = try await speakerService.getAllConversations()
            } catch {
                // Handle error
            }
        }
    }
}
```

#### 3.2 Add Real-time Sync
**Modify:** `listener/VoiceActivityRecorder.swift`

```swift
// Add auto-upload after recording
private func saveClipToDisk(audioData: Data, startTime: Date) {
    // Existing save logic...
    
    // Auto-upload to backend
    Task {
        do {
            let _ = try await speakerIDService.uploadConversation(
                audioFileURL: fileURL,
                displayName: nil
            )
        } catch {
            print("Auto-upload failed: \(error)")
        }
    }
}
```

---

## 🔧 Technical Implementation Details

### API Integration Patterns

#### Error Handling
```swift
enum SpeakerIDError: Error, LocalizedError {
    case networkError(Error)
    case serverError(Int)
    case invalidResponse
    case uploadFailed
    
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
        }
    }
}
```

#### HTTP Client
```swift
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
```

#### File Upload
```swift
private func uploadAudioFile(url: URL, displayName: String?) async throws -> ConversationResponse {
    let uploadURL = URL(string: "\(baseURL)/api/conversations/upload")!
    
    var request = URLRequest(url: uploadURL)
    request.httpMethod = "POST"
    
    let boundary = UUID().uuidString
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    
    var body = Data()
    
    // Add audio file
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
    body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
    body.append(try Data(contentsOf: url))
    body.append("\r\n".data(using: .utf8)!)
    
    // Add display name if provided
    if let displayName = displayName {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"display_name\"\r\n\r\n".data(using: .utf8)!)
        body.append(displayName.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
    }
    
    body.append("--\(boundary)--\r\n".data(using: .utf8)!)
    
    request.httpBody = body
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse,
          200...299 ~= httpResponse.statusCode else {
        throw SpeakerIDError.uploadFailed
    }
    
    return try JSONDecoder().decode(ConversationResponse.self, from: data)
}
```

### Data Synchronization

#### Local Cache Management
```swift
class ConversationCache {
    private let cacheURL: URL
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheURL = documentsPath.appendingPathComponent("ConversationCache")
        createCacheDirectory()
    }
    
    func save(conversation: ConversationDetail) {
        let fileURL = cacheURL.appendingPathComponent("\(conversation.id).json")
        do {
            let data = try JSONEncoder().encode(conversation)
            try data.write(to: fileURL)
        } catch {
            print("Failed to cache conversation: \(error)")
        }
    }
    
    func load(conversationId: String) -> ConversationDetail? {
        let fileURL = cacheURL.appendingPathComponent("\(conversationId).json")
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(ConversationDetail.self, from: data)
        } catch {
            return nil
        }
    }
}
```

#### Offline Support
```swift
class OfflineUploadManager {
    private var pendingUploads: [URL] = []
    
    func queueUpload(_ audioURL: URL) {
        pendingUploads.append(audioURL)
        UserDefaults.standard.set(pendingUploads.map(\.path), forKey: "pendingUploads")
    }
    
    func processPendingUploads() async {
        for audioURL in pendingUploads {
            do {
                let _ = try await speakerIDService.uploadConversation(audioFileURL: audioURL, displayName: nil)
                removePendingUpload(audioURL)
            } catch {
                print("Failed to upload queued file: \(error)")
                break // Stop processing on first failure
            }
        }
    }
}
```

---

## 🚀 Migration Timeline

### Day 1: Foundation
- [ ] Create `SpeakerIDService.swift`
- [ ] Add new data models
- [ ] Implement basic upload functionality
- [ ] Test audio file upload

### Day 2: Integration
- [ ] Replace local transcription in `ContentView.swift`
- [ ] Add error handling and loading states
- [ ] Implement conversation detail fetching
- [ ] Test end-to-end flow

### Day 3: Speaker Features
- [ ] Add speaker management API calls
- [ ] Create `SpeakerManagementView.swift`
- [ ] Implement Pinecone speaker training
- [ ] Add speaker identification display

### Day 4: Enhancement
- [ ] Add conversation list from backend
- [ ] Implement real-time sync
- [ ] Add offline upload queue
- [ ] Polish UI and error handling

### Day 5: Testing & Optimization
- [ ] Test all features thoroughly
- [ ] Optimize performance
- [ ] Add comprehensive error handling
- [ ] Document new features

---

## 📝 Files to Modify

### New Files:
- `listener/SpeakerIDService.swift` - API integration layer
- `listener/SpeakerManagementView.swift` - Speaker management UI
- `listener/ConversationListView.swift` - Backend conversation list
- `listener/ConversationCache.swift` - Local caching
- `listener/OfflineUploadManager.swift` - Offline support

### Modified Files:
- `listener/DataModels.swift` - Add backend response models
- `listener/ContentView.swift` - Replace transcription flow
- `listener/VoiceActivityRecorder.swift` - Add auto-upload
- `listener/TranscriptionDetailView.swift` - Support new data format

### Deprecated Files:
- `listener/Summarize.swift` - Replace with backend
- `listener/Transcribe.swift` - Replace with backend

---

## 🎯 Success Metrics

1. **Functionality**: All existing features work with backend
2. **Performance**: Upload and processing within 30 seconds
3. **Reliability**: 95% upload success rate
4. **User Experience**: Seamless transition, no workflow disruption
5. **Features**: Speaker identification actually works vs current local-only approach

---

## 🔒 Configuration Required

### Environment Setup
Add to `Info.plist`:
```xml
<key>SpeakerIDServerURL</key>
<string>https://speaker-id-server-production.up.railway.app</string>
```

### API Keys (if needed)
Currently the backend doesn't require authentication, but monitor usage and add if needed.

---

## 🎉 Benefits After Integration

1. **Real Speaker ID**: Actual voice fingerprinting vs current basic transcription
2. **Web Dashboard**: Access conversations on any device
3. **Better Accuracy**: Backend handles speaker diarization properly
4. **Team Features**: Share conversations and speaker profiles
5. **Scalability**: Leverage cloud infrastructure vs device limitations 