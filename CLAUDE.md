# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Listener Pro** is a cross-platform iOS/macOS SwiftUI app that records audio with voice activity detection, uploads to a Speaker ID backend for processing, and provides conversation management with speaker identification.

### Architecture
- **Frontend**: SwiftUI iOS/macOS app with real-time audio processing
- **Backend**: FastAPI-based Speaker ID Server at `https://speaker-id-server-production.up.railway.app`
- **Database**: PostgreSQL + Pinecone vector database for voice embeddings (backend)
- **Storage**: AWS S3 for audio files (backend)

## Build Commands

### iOS/macOS App
```bash
# Open in Xcode
open listener.xcodeproj

# Build from command line  
xcodebuild -project listener.xcodeproj -scheme listener -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run SwiftLint code style checks
swiftlint

# Fix auto-correctable SwiftLint violations
swiftlint --fix

# Clean build if needed
rm -rf ~/Library/Developer/Xcode/DerivedData/listener-*
```

### No Additional Dependencies
- No package.json, Podfile, or other dependency managers
- Pure Xcode project with no external build tools required

## Project Structure

```
listener/
├── Views/                    (All SwiftUI views)
├── DesignSystem/             (Unified design system components)
├── VoiceActivityRecorder.swift    (Core audio capture)
├── SpeakerIDService.swift         (Backend API client) 
├── DataModels.swift               (API models)
├── AppNavigationManager.swift     (Cross-platform navigation)
├── CircularAudioBuffer.swift      (Audio buffering)
└── listenerApp.swift              (App entry point)
```

## Core Architecture

### Platform-Specific App Entry
- **iOS**: DashboardView with tab navigation
- **macOS**: Sidebar navigation with MacContentView
- Conditional compilation using `#if os(macOS)` throughout

### Audio Pipeline
- `VoiceActivityRecorder.swift` - Core audio capture using AVAudioEngine
- `CircularAudioBuffer.swift` - Real-time buffering for seamless recording
- Voice activity detection with configurable silence thresholds (1-60s)
- Automatic clip segmentation when speech is detected

### Backend Integration
- `SpeakerIDService.swift` - Complete API client for Speaker ID Server
- RESTful API communication with async/await pattern
- Upload audio files for speaker identification processing
- Manage speakers, conversations, and Pinecone voice embeddings

### Design System
- `DesignSystem/` folder contains unified UI components
- `Colors.swift`, `Typography.swift`, `Spacing.swift`, `Icons.swift` for design tokens
- `Components.swift` with reusable SwiftUI components (AppScrollContainer, AppSectionHeader, etc.)
- `Theme.swift` for global theme settings

### Navigation Architecture
- `AppNavigationManager.swift` manages cross-platform navigation state
- iOS uses tab-based navigation via DashboardView
- macOS uses sidebar navigation with detail views
- Shared navigation logic for conversation detail routing

## Key Backend API Endpoints

```
Base URL: https://speaker-id-server-production.up.railway.app

POST /api/conversations/upload          - Upload audio files
GET  /api/conversations                 - List all conversations  
GET  /api/conversations/{id}            - Get conversation details
PUT  /api/conversations/{id}            - Update conversation
GET  /api/speakers                      - List speakers
POST /api/speakers                      - Create speaker
PUT  /api/speakers/{id}                 - Update speaker
GET  /api/pinecone/speakers             - List Pinecone speakers
POST /api/pinecone/speakers/link        - Link speaker to Pinecone
POST /api/utterances/{id}               - Update utterance text/speaker
```

## Development Workflow

1. **Build**: Use Xcode exclusively - no CLI tools needed
2. **Testing**: Manual testing via iOS Simulator or physical device
3. **Permissions**: App requires microphone access for audio recording
4. **Debugging**: Use Xcode debugger and console for print statements

## Data Models

Key models in `DataModels.swift`:
- `ConversationResponse` - Upload response from backend
- `BackendConversationSummary` - Conversation list item
- `ConversationDetail` - Full conversation with utterances
- `SpeakerIDUtterance` - Individual speech segment with speaker
- `Speaker` - Speaker profile with Pinecone linking

## Platform Differences

- **iOS**: Tab navigation, mobile-optimized touch controls, portrait orientation
- **macOS**: Sidebar navigation, larger screens, keyboard shortcuts, resizable windows
- **Shared**: Core recording logic, API communication, and data models identical

## Development Notes

- **Xcode Version**: Requires Xcode 16.2+ with iOS 18.2+ SDK  
- **Deployment Target**: iOS 18.2, macOS 15.0+
- **Audio Permissions**: Required for microphone access during development
- **Background Processing**: App supports background audio monitoring
- **Error Handling**: Consistent async/await pattern with proper error propagation
- **No Tests**: Currently no automated test suite - relies on manual testing

## Code Quality

### SwiftLint Integration
- `.swiftlint.yml` configured for SwiftUI development patterns
- Custom rules encourage design system usage
- Snake_case API field names excluded from identifier rules
- Run `swiftlint` to check violations, `swiftlint --fix` for auto-corrections
- **Build Phase Setup**: Add SwiftLint to Xcode build phases:
  1. In Xcode: Target → Build Phases → + → New Run Script Phase
  2. Name: "SwiftLint"
  3. Script: `if [ -f ~/opt/homebrew/bin/swiftlint ]; then ~/opt/homebrew/bin/swiftlint; elif command -v swiftlint >/dev/null 2>&1; then swiftlint; else echo "warning: SwiftLint not installed"; fi`
  4. Input Files: `$(SRCROOT)/.swiftlint.yml`