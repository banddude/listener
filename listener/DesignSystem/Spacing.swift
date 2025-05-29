//
//  Spacing.swift
//  listener
//
//  Created by Mike Shaffer on 5/28/25.
//

import SwiftUI

// Define standard spacing units for consistent layout.

struct AppSpacing {
    /// 4.0
    static let extraSmall: CGFloat = 4.0
    /// 8.0
    static let small: CGFloat = 8.0
    /// 12.0
    static let mediumSmall: CGFloat = 12.0
    /// 16.0
    static let medium: CGFloat = 16.0
    /// 20.0
    static let mediumLarge: CGFloat = 20.0
    /// 24.0
    static let large: CGFloat = 24.0
    /// 32.0
    static let extraLarge: CGFloat = 32.0
    /// 48.0
    static let xxLarge: CGFloat = 48.0
}

// Example of how to use with padding:
// .padding(.horizontal, AppSpacing.medium)
// .padding(.vertical, AppSpacing.small)

// Or in a VStack/HStack:
// VStack(spacing: AppSpacing.medium) { ... }
