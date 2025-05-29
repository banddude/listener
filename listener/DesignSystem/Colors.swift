//
//  Colors.swift
//  listener
//
//  Created by Mike Shaffer on 5/28/25.
//

import SwiftUI

// Define your app's color palette here.
// It's good practice to use named colors from your asset catalog
// to support light/dark mode automatically.

extension Color {
    static let primaryBackground = Color("PrimaryBackgroundColor") // Example: Define in Assets.xcassets
    static let secondaryBackground = Color("SecondaryBackgroundColor")
    static let primaryText = Color("PrimaryTextColor")
    static let secondaryText = Color("SecondaryTextColor")
    static let accent = Color("AccentColor") // Usually defined in Assets.xcassets by default

    static let destructive = Color.red
    static let success = Color.green
    static let warning = Color.orange

    // You can also define specific UI element colors
    static let buttonPrimaryBackground = accent
    static let buttonPrimaryText = Color.white

    static let cardBackground = Color("CardBackgroundColor")
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