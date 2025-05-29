//
//  Theme.swift
//  listener
//
//  Created by Mike Shaffer on 5/28/25.
//

import SwiftUI

// This file can be used to define global theme settings,
// such as light/dark mode preferences or other app-wide styling configurations.

struct AppTheme {
    // Example: Define a default corner radius
    static let cornerRadius: CGFloat = 12.0

    // Example: Define a general animation
    static let defaultAnimation: Animation = .easeInOut
}

// You might also define extensions or modifiers related to the overall theme.
extension View {
    func standardShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
} 
