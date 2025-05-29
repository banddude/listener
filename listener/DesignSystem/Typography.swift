//
//  Typography.swift
//  listener
//
//  Created by Mike Shaffer on 5/28/25.
//

import SwiftUI

// Define your app's typography styles here.
// This can include custom fonts, standard font sizes, and weights.

extension Font {
    static func appFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Replace "YourAppFontName" with your actual custom font if you have one
        // otherwise, systemFont will be used.
        // Example: Font.custom("YourAppFontName-Regular", size: size)
        return .system(size: size, weight: weight)
    }

    static let largeTitle = appFont(size: 34, weight: .bold)
    static let title1 = appFont(size: 28, weight: .bold)
    static let title2 = appFont(size: 22, weight: .semibold)
    static let title3 = appFont(size: 20, weight: .semibold)
    static let headline = appFont(size: 17, weight: .semibold)
    static let body = appFont(size: 17)
    static let callout = appFont(size: 16)
    static let subheadline = appFont(size: 15, weight: .medium)
    static let footnote = appFont(size: 13)
    static let caption1 = appFont(size: 12)
    static let caption2 = appFont(size: 11, weight: .medium)
}

// You can also create ViewModifiers for applying text styles if needed.
struct HeadlineTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.headline)
            .foregroundColor(Color.primaryText) // Corrected reference from earlier
    }
}

extension View {
    func headlineStyle() -> some View {
        self.modifier(HeadlineTextStyle())
    }
}
