//
//  Icons.swift
//  listener
//
//  Created by Mike Shaffer on 5/28/25.
//

import SwiftUI

// Define commonly used icons throughout the app for consistency
// All icons extracted from current app usage

struct AppIcons {
    // MARK: - Navigation & Interface
    static let dashboard = "square.grid.2x2"
    static let refresh = "arrow.clockwise"
    static let add = "plus"
    static let cancel = "xmark"
    static let search = "magnifyingglass"
    
    // MARK: - Recording & Audio
    static let record = "record.circle"
    static let recording = "waveform"
    static let microphone = "mic"
    static let microphoneFill = "mic.fill"
    static let speaker = "speaker.wave.2"
    static let audioWave = "waveform.path"
    
    // MARK: - People & Communication
    static let person = "person"
    static let people = "person.2"
    static let conversation = "bubble.left.and.bubble.right"
    static let chat = "message"
    static let speakerGroup = "person.3"
    
    // MARK: - Data & Upload
    static let upload = "icloud.and.arrow.up"
    static let download = "icloud.and.arrow.down"
    static let cloud = "icloud"
    static let document = "doc"
    static let folder = "folder"
    
    // MARK: - Status & Indicators
    static let checkmark = "checkmark"
    static let error = "exclamationmark.triangle"
    static let warning = "exclamationmark.circle"
    static let info = "info.circle"
    static let loading = "arrow.2.circlepath"
    
    // MARK: - Tab Navigation (from current app)
    static let tabRecorder = "record.circle"
    static let tabConversations = "bubble.left.and.bubble.right"
    static let tabSpeakers = "person.2"
    static let tabSharedUploads = "tray.and.arrow.down"
    static let tabUpload = "icloud.and.arrow.up"
    static let tabPinecone = "magnifyingglass"
    
    // MARK: - Content States
    static let emptyState = "tray"
    static let noConversations = "bubble.left.and.bubble.right"
    static let noSpeakers = "person.2"
    static let noRecordings = "waveform.slash"
}

// MARK: - Icon Helper Extensions
extension Image {
    // MARK: - Navigation Icons
    static let dashboard = Image(systemName: AppIcons.dashboard)
    static let refresh = Image(systemName: AppIcons.refresh)
    static let add = Image(systemName: AppIcons.add)
    static let cancel = Image(systemName: AppIcons.cancel)
    static let search = Image(systemName: AppIcons.search)
    
    // MARK: - Recording Icons
    static let record = Image(systemName: AppIcons.record)
    static let recording = Image(systemName: AppIcons.recording)
    static let microphone = Image(systemName: AppIcons.microphone)
    static let speaker = Image(systemName: AppIcons.speaker)
    
    // MARK: - People Icons
    static let person = Image(systemName: AppIcons.person)
    static let people = Image(systemName: AppIcons.people)
    static let conversation = Image(systemName: AppIcons.conversation)
    
    // MARK: - Upload Icons
    static let upload = Image(systemName: AppIcons.upload)
    static let download = Image(systemName: AppIcons.download)
    static let cloud = Image(systemName: AppIcons.cloud)
    
    // MARK: - Status Icons
    static let checkmark = Image(systemName: AppIcons.checkmark)
    static let error = Image(systemName: AppIcons.error)
    static let warning = Image(systemName: AppIcons.warning)
    static let info = Image(systemName: AppIcons.info)
    static let loading = Image(systemName: AppIcons.loading)
}

// MARK: - Icon Styling Extensions
extension View {
    func iconStyle(size: CGFloat = 16, color: Color = .primaryText) -> some View {
        self
            .font(.system(size: size))
            .foregroundColor(color)
    }
    
    func tabIconStyle(size: CGFloat = 14) -> some View {
        self.iconStyle(size: size, color: .tabUnselected)
    }
    
    func selectedTabIconStyle(size: CGFloat = 14) -> some View {
        self.iconStyle(size: size, color: .tabSelected)
    }
    
    func statusIconStyle(size: CGFloat = 12, color: Color) -> some View {
        self.iconStyle(size: size, color: color)
    }
}
