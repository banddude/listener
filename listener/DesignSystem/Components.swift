//
//  Components.swift
//  listener
//
//  Created by Mike Shaffer on 5/28/25.
//

import SwiftUI

// Define reusable UI components here.

// MARK: - Buttons

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(Color.buttonPrimaryText)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.buttonPrimaryBackground)
            .cornerRadius(AppTheme.cornerRadius)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(AppTheme.defaultAnimation, value: configuration.isPressed)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundColor(Color.accent)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.accent.opacity(0.15))
            .cornerRadius(AppTheme.cornerRadius)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(AppTheme.defaultAnimation, value: configuration.isPressed)
    }
}

// MARK: - Cards

struct StandardCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(AppTheme.cornerRadius)
            .standardShadow()
    }
}

// MARK: - Example Usage (for Previews or testing)

#if DEBUG
struct ComponentsPreview: View {
    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            Button("Primary Action") { }
                .buttonStyle(PrimaryActionButtonStyle())

            Button("Secondary Action") { }
                .buttonStyle(SecondaryActionButtonStyle())

            StandardCard {
                Text("This is content inside a standard card. It uses the defined card background, corner radius, and shadow.")
                    .font(.body)
            }
        }
        .padding()
        .background(Color.secondaryBackground)
    }
}

#Preview {
    ComponentsPreview()
}
#endif
