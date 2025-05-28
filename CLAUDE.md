# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Listener Pro** is a hybrid iOS/macOS app with cloud backend integration that transforms devices into intelligent meeting companions. The app records audio, performs speaker identification, and provides real-time transcription with speaker attribution.

### Architecture
- **Frontend**: SwiftUI iOS/macOS app with real-time audio processing
- **Backend**: FastAPI-based Speaker ID Server (deployed separately)
- **Database**: PostgreSQL + Pinecone vector database for voice embeddings
- **Storage**: AWS S3 for audio files

## Build Commands

### iOS/macOS App
```bash
# Open in Xcode
open listener.xcodeproj

# Build from command line (if xcodebuild needed)
xcodebuild -project listener.xcodeproj -scheme listener -destination 'platform=iOS Simulator,name=iPhone 15' build
```

### Backend (Reference Only)
The Python backend is deployed separately. Local requirements are in `requirements.txt` but not used in this repository.

## Development Workflow

1. **Build**: Use Xcode - no additional build scripts required
2. **Testing**: No automated tests currently - manual testing via iOS Simulator or device
3. **Permissions**: App requires microphone and speech recognition permissions for testing

## Key Components

### Audio Pipeline
- `VoiceActivityRecorder.swift` - Core audio capture and voice activity detection
- `CircularAudioBuffer.swift` - Real-time buffering for seamless recording  
- Uses AVAudioEngine and SFSpeechRecognizer

### Backend Integration  
- `SpeakerIDService.swift` - API client for Speaker ID Server
- `DataModels.swift` - Shared models for API communication
- Base URL: `https://speaker-id-server-production.up.railway.app`

### UI Architecture
- Cross-platform SwiftUI with conditional compilation
- `ContentView.swift` - Main recording interface
- `DashboardView.swift` - Analytics and conversation management
- Navigation: iOS uses tabs, macOS uses sidebar

## Integration Status

Currently in **Phase 2** of backend integration:
- ✅ API integration layer complete
- ✅ Conversation upload working
- 🚧 Speaker management UI in progress
- 📋 Dashboard features planned

## File Patterns

### Core Audio Files
- `*Recorder.swift` - Audio capture and processing
- `*Buffer.swift` - Audio buffering utilities

### UI Views  
- `*View.swift` - SwiftUI view components
- `ContentView.swift` - Main app interface

### Backend Integration
- `SpeakerIDService.swift` - All API communications
- `DataModels.swift` - API request/response models

## Development Notes

- **Xcode Version**: Requires Xcode 16.2+ with iOS 17.0+ SDK
- **Device Testing**: Microphone access requires physical device or permissions setup
- **Background Processing**: App supports background audio monitoring
- **Error Handling**: Uses async/await pattern with proper error propagation

## Backend API Endpoints

Key endpoints integrated:
- `POST /api/conversations/upload` - Upload audio files
- `GET /api/conversations/{id}` - Retrieve conversation details  
- `GET /api/speakers` - Speaker management
- `POST /api/pinecone/speakers` - Voice profile training

## Platform Differences

- **iOS**: Tab-based navigation, mobile-optimized controls
- **macOS**: Sidebar navigation, desktop keyboard shortcuts
- **Shared**: Core recording and processing logic identical