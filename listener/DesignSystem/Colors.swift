//
//  Colors.swift
//  listener
//
//  Created by Mike Shaffer on 5/28/25.
//

import SwiftUI

// Define your app's color palette here.
// Colors are extracted from current app usage to maintain exact visual consistency

extension Color {
    // MARK: - Background Colors
    static let primaryBackground = Color(.systemGroupedBackground) // Used in ListenerView
    static let secondaryBackground = Color(.secondarySystemGroupedBackground)
    static let cardBackground = Color(.systemBackground) // For cards and containers
    
    // MARK: - Text Colors
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    
    // MARK: - Accent & Brand Colors
    static let accent = Color.blue // Primary brand color used throughout
    static let accentLight = Color.blue.opacity(0.1) // For selected states
    static let accentMedium = Color.blue.opacity(0.15) // For button backgrounds
    
    // MARK: - Semantic Colors
    static let destructive = Color.red
    static let destructiveLight = Color.red.opacity(0.1) // For error backgrounds
    static let success = Color.green
    static let successLight = Color.green.opacity(0.1) // For success backgrounds
    static let warning = Color.orange
    static let warningLight = Color.orange.opacity(0.1) // For warning backgrounds
    
    // MARK: - Status Colors (from app usage)
    static let recordingActive = Color.green // Recording indicator
    static let recordingInactive = Color.red // Ready state
    static let speechDetected = Color.blue // Speech detection
    static let recordingInProgress = Color.red // Active recording
    
    // MARK: - UI Element Colors
    static let tabSelected = accent
    static let tabUnselected = Color.gray
    static let tabSelectedBackground = accentLight
    
    // MARK: - Card & Container Colors
    static let cardBorder = Color.gray.opacity(0.2)
    static let cardElevated = Color(.tertiarySystemBackground)
    static let lightGrayBackground = Color.gray.opacity(0.05)
    static let mediumGrayBackground = Color.gray.opacity(0.08)
    static let divider = Color.gray.opacity(0.3)
    
    // MARK: - Button Colors
    static let buttonPrimaryBackground = accent
    static let buttonPrimaryText = Color.white
    static let buttonSecondaryBackground = accentMedium
    static let buttonSecondaryText = accent
    
    // MARK: - Material Alternatives
    static let materialLight = Color(.systemBackground)
    static let materialMedium = Color(.secondarySystemBackground)
    static let materialHeavy = Color(.tertiarySystemBackground)
}

// Helper for hex colors if needed, though asset catalog is preferred.
// extension Color {
//    init(hex: String) {
//        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
//        var int: UInt64 = 0
//        Scanner(string: hex).scanHexInt64(&int)
//        let a, r, g, b: UInt64
//        switch hex.count {
//        case 3: // RGB (12-bit)
//            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
//        case 6: // RGB (24-bit)
//            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
//        case 8: // ARGB (32-bit)
//            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
//        default:
//            (a, r, g, b) = (255, 0, 0, 0)
//        }
//        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
//    }
// } 
