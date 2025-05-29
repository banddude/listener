//
//  Typography.swift
//  listener
//
//  Created by Mike Shaffer on 5/28/25.
//

import SwiftUI

// Define your app's typography styles here.
// Typography extracted from current app usage to maintain exact visual consistency

extension Font {
    // MARK: - App Typography System
    static func appFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight)
    }

    // MARK: - Standard Typography Scale (matching iOS defaults)
    static let largeTitle = appFont(size: 34, weight: .bold)
    static let title1 = appFont(size: 28, weight: .bold)
    static let title2 = appFont(size: 22, weight: .semibold) // Used in headers
    static let title3 = appFont(size: 20, weight: .semibold)
    static let headline = appFont(size: 17, weight: .semibold) // Used in lists, cards
    static let body = appFont(size: 17) // Standard body text
    static let callout = appFont(size: 16)
    static let subheadline = appFont(size: 15, weight: .medium) // Used in subtitles
    static let footnote = appFont(size: 13) // Used in small text
    static let caption1 = appFont(size: 12)
    static let caption2 = appFont(size: 11, weight: .medium) // Used in tab buttons
    
    // MARK: - App-Specific Typography (from current usage)
    // Tab Button Typography (responsive sizing from ResponsiveTabButton)
    static let tabButtonLarge = footnote
    static let tabButtonMedium = caption1
    static let tabButtonSmall = caption2
    
    // Status Text Typography
    static let statusText = subheadline
    static let statusDetail = caption1
    
    // Header Typography
    static let sectionHeader = headline
    static let viewTitle = title2
    static let cardTitle = headline
}

// MARK: - Text Style View Modifiers
struct AppTextStyle: ViewModifier {
    let font: Font
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundColor(color)
    }
}

extension View {
    // MARK: - Semantic Text Styles
    func appTitle() -> some View {
        self.modifier(AppTextStyle(font: .title2, color: Color.primaryText))
    }
    
    func appHeadline() -> some View {
        self.modifier(AppTextStyle(font: .headline, color: Color.primaryText))
    }
    
    func appBody() -> some View {
        self.modifier(AppTextStyle(font: .body, color: Color.primaryText))
    }
    
    func appSubtitle() -> some View {
        self.modifier(AppTextStyle(font: .subheadline, color: Color.secondaryText))
    }
    
    func appCaption() -> some View {
        self.modifier(AppTextStyle(font: .caption1, color: Color.secondaryText))
    }
    
    // MARK: - Status Text Styles
    func statusActive() -> some View {
        self.modifier(AppTextStyle(font: .statusText, color: Color.recordingActive))
    }
    
    func statusInactive() -> some View {
        self.modifier(AppTextStyle(font: .statusText, color: Color.recordingInactive))
    }
    
    func statusDetected() -> some View {
        self.modifier(AppTextStyle(font: .statusDetail, color: Color.speechDetected))
    }
}
