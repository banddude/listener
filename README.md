# Listener Pro - iOS Audio Recording & Speaker ID App

## Overview

**Listener Pro** is a cross-platform iOS/macOS SwiftUI app that transforms your device into an intelligent meeting companion. It records audio with voice activity detection, uploads conversations to a Speaker ID backend for processing, and provides conversation management with speaker identification.

## What Listener Pro Does

### 🎯 **Smart Audio Recording**
- **Voice Activity Detection**: Automatically starts/stops recording based on speech detection
- **Configurable Thresholds**: Set silence detection from 1-60 seconds
- **Real-time Feedback**: Visual indicators for listening, speech detection, and recording status
- **Automatic Segmentation**: Creates individual audio clips when voice activity is detected

### 📱 **Cross-Platform Experience**
- **iOS**: Tab-based navigation optimized for mobile touch interface
- **macOS**: Sidebar navigation with larger screen layouts and keyboard shortcuts
- **Shared Logic**: Core recording and API integration identical across platforms

### 🔄 **Backend Integration**
- **Speaker ID Server**: Uploads audio to `https://speaker-id-server-production.up.railway.app`
- **Speaker Recognition**: Processes audio for individual speaker identification
- **Conversation Management**: View, edit, and organize processed conversations
- **Speaker Profiles**: Link speakers to Pinecone voice embeddings for improved recognition

## Core Features

### 📲 **Recording & Processing**
- Voice activity detection with real-time visual feedback
- Audio buffering for seamless recording experience
- Upload conversations to backend for speaker ID processing
- Conversation playback with individual utterance controls

### 💬 **Conversation Management**
- View all processed conversations with speaker attribution
- Individual utterance playback and editing
- Speaker assignment editing with bulk update options
- Conversation renaming and organization

### 📥 **Share Extension**
- Import audio files from other apps via iOS share sheet
- Works with Voice Memos, Files app, and any audio source
- Supports common formats: mp3, wav, m4a, aac, ogg, flac, and more
- Automatic audio validation and processing on import
- Background processing when main app opens

### 👥 **Speaker Management**
- View all identified speakers with statistics
- Add new speakers manually
- Link speakers to Pinecone voice profiles for better recognition
- Edit speaker assignments across conversations

### 🎨 **Design System**
- Unified design system with consistent components
- Cross-platform UI components that adapt to iOS/macOS
- Semantic design tokens for colors, typography, and spacing

## Technical Architecture

### App Structure
```
listener/
├── Views/                         (All SwiftUI views)
├── DesignSystem/                  (Unified UI components)
├── VoiceActivityRecorder.swift    (Core audio capture)
├── SpeakerIDService.swift         (Backend API client) 
├── DataModels.swift               (API models)
├── AppNavigationManager.swift     (Cross-platform navigation)
├── AppLifecycleManager.swift      (App lifecycle and background processing)
├── SharedAudioManager.swift       (Shared container audio management)
├── CircularAudioBuffer.swift      (Audio buffering)
├── listenerApp.swift              (App entry point)
└── ListenerShareExtension/        (iOS share extension)
    └── ShareViewController.swift  (Share sheet audio handler)
```

### Core Components
- **Audio Pipeline**: AVAudioEngine-based recording with voice activity detection
- **Backend Integration**: RESTful API client for Speaker ID Server
- **Navigation**: Cross-platform navigation manager supporting iOS tabs and macOS sidebar
- **Design System**: Reusable SwiftUI components for consistent UI
- **Share Extension**: iOS extension for importing audio files from other apps
- **Shared Container**: App group for cross-app file sharing with metadata preservation

### Backend Integration
**Base URL**: `https://speaker-id-server-production.up.railway.app`

Key API endpoints used:
- `POST /api/conversations/upload` - Upload audio files for processing
- `GET /api/conversations` - List all conversations  
- `GET /api/conversations/{id}` - Get detailed conversation with utterances
- `GET /api/speakers` - Manage speaker profiles
- `PUT /api/utterances/{id}` - Edit utterance text or speaker assignment

## Development

### Requirements
- **Xcode 16.2+** with iOS 18.2+ SDK
- **iOS 18.2+** / **macOS 15.0+** deployment targets
- **Microphone permissions** required for audio recording

### Build Commands
```bash
# Open in Xcode
open listener.xcodeproj

# Build from command line
xcodebuild -project listener.xcodeproj -scheme listener -destination 'platform=iOS Simulator,name=iPhone 16' build

# Clean build if needed
rm -rf ~/Library/Developer/Xcode/DerivedData/listener-*
```

### No External Dependencies
- Pure Xcode project with no package managers
- No CocoaPods, SPM, or npm dependencies
- Self-contained SwiftUI application

## Platform Differences

### iOS Features
- Tab-based navigation (Recorder, Conversations, Speakers, Dashboard)
- Mobile-optimized touch controls and layouts
- Portrait orientation support

### macOS Features  
- Sidebar navigation with detail views
- Larger screen layouts with more information density
- Keyboard shortcuts and desktop interaction patterns
- Resizable windows with minimum size constraints

### Shared Features
- Identical audio recording and voice activity detection
- Same backend API integration and data models
- Consistent design system and UI components
- Cross-platform conversation and speaker management

## Current Status

This is a **production iOS/macOS app** that:
- ✅ Successfully records audio with voice activity detection
- ✅ Uploads conversations to Speaker ID backend for processing  
- ✅ Displays processed conversations with speaker identification
- ✅ Provides full conversation and speaker management UI
- ✅ Works on both iOS and macOS with platform-appropriate UX
- ✅ Accepts audio file imports via iOS share extension
- ✅ Auto-processes shared audio files on app launch

## Related Documentation

- **API Integration**: See `README_API.md` for complete backend API documentation
- **Development Guide**: See `CLAUDE.md` for codebase architecture and development workflow

---

**Listener Pro transforms conversations into actionable insights with intelligent speaker identification.**