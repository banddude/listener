//
//  Spacing.swift
//  listener
//
//  Created by Mike Shaffer on 5/28/25.
//

import SwiftUI

// Define standard spacing units for consistent layout.
// Spacing values extracted from current app usage to maintain exact visual consistency

struct AppSpacing {
    // MARK: - Base Spacing Scale
    /// 2.0 - Minimal spacing
    static let minimal: CGFloat = 2.0
    /// 3.0 - For tab button spacing
    static let tiny: CGFloat = 3.0
    /// 4.0 - Extra small spacing
    static let extraSmall: CGFloat = 4.0
    /// 8.0 - Small spacing (used in tab layout, small gaps)
    static let small: CGFloat = 8.0
    /// 12.0 - Medium-small spacing (used in LazyVStack)
    static let mediumSmall: CGFloat = 12.0
    /// 16.0 - Medium spacing (most common, used in VStack, padding)
    static let medium: CGFloat = 16.0
    /// 20.0 - Medium-large spacing (used in main VStack layouts)
    static let mediumLarge: CGFloat = 20.0
    /// 24.0 - Large spacing
    static let large: CGFloat = 24.0
    /// 32.0 - Extra large spacing
    static let extraLarge: CGFloat = 32.0
    /// 40.0 - For empty state padding
    static let xl: CGFloat = 40.0
    /// 48.0 - XX Large spacing
    static let xxLarge: CGFloat = 48.0
    
    // MARK: - App-Specific Spacing (from current usage)
    /// 60.0 - Tab bar height
    static let tabBarHeight: CGFloat = 60.0
    /// 50.0 - Tab button height
    static let tabButtonHeight: CGFloat = 50.0
    /// 70.0 - Minimum tab button width threshold
    static let tabButtonMinWidth: CGFloat = 70.0
    /// 80.0 - Medium tab button width threshold
    static let tabButtonMediumWidth: CGFloat = 80.0
    
    // MARK: - Container Spacing
    /// Standard padding for main content areas
    static let containerPadding = medium
    /// Standard spacing between sections
    static let sectionSpacing = mediumLarge
    /// Standard spacing between list items
    static let listItemSpacing = mediumSmall
    /// Standard spacing between card elements
    static let cardSpacing = medium
}

// MARK: - Convenience Extensions
extension EdgeInsets {
    /// Standard container padding for all sides
    static let container = EdgeInsets(top: AppSpacing.medium, leading: AppSpacing.medium, bottom: AppSpacing.medium, trailing: AppSpacing.medium)
    
    /// Horizontal padding only
    static let horizontal = EdgeInsets(top: 0, leading: AppSpacing.medium, bottom: 0, trailing: AppSpacing.medium)
    
    /// Vertical padding only
    static let vertical = EdgeInsets(top: AppSpacing.medium, leading: 0, bottom: AppSpacing.medium, trailing: 0)
}

// Example of how to use with padding:
// .padding(.horizontal, AppSpacing.medium)
// .padding(.vertical, AppSpacing.small)
// .padding(.container)

// Or in a VStack/HStack:
// VStack(spacing: AppSpacing.sectionSpacing) { ... }
