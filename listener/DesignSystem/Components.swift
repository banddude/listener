//
//  Components.swift
//  listener
//
//  Created by Mike Shaffer on 5/28/25.
//

import SwiftUI

// Define reusable UI components here.
// Components extracted from current app patterns to maintain exact visual consistency

// MARK: - Button Styles

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(Color.buttonPrimaryText)
            .padding(AppSpacing.medium)
            .frame(maxWidth: .infinity)
            .background(Color.buttonPrimaryBackground)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut, value: configuration.isPressed)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundColor(Color.buttonSecondaryText)
            .padding(AppSpacing.medium)
            .frame(maxWidth: .infinity)
            .background(Color.buttonSecondaryBackground)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut, value: configuration.isPressed)
    }
}

// MARK: - Tab Button Component (from ResponsiveTabButton)

struct AppTabButton: View {
    let title: String
    let iconName: String
    let isSelected: Bool
    let width: CGFloat
    let action: () -> Void
    
    private var fontSize: Font {
        if width < AppSpacing.tabButtonMinWidth || title.count > 8 {
            return .tabButtonSmall
        } else if width < AppSpacing.tabButtonMediumWidth {
            return .tabButtonMedium
        } else {
            return .tabButtonLarge
        }
    }
    
    private var iconSize: CGFloat {
        width < AppSpacing.tabButtonMinWidth ? 12 : 14
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.tiny) {
                Image(systemName: iconName)
                    .font(.system(size: iconSize))
                Text(title)
                    .font(fontSize)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundColor(isSelected ? .tabSelected : .tabUnselected)
            .frame(width: width, height: AppSpacing.tabButtonHeight)
            .background(
                isSelected ? Color.tabSelectedBackground : Color.clear
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
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
            .padding(AppSpacing.medium)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .standardShadow()
    }
}

// MARK: - Empty State Component

struct AppEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondaryText)
            
            Text(title)
                .appHeadline()
            
            Text(subtitle)
                .appSubtitle()
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
    }
}

// MARK: - Loading State Component

struct AppLoadingState: View {
    let message: String
    
    var body: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text(message)
                .appCaption()
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.medium)
    }
}

// MARK: - Status Indicator Component

struct AppStatusIndicator: View {
    let isActive: Bool
    let activeText: String
    let inactiveText: String
    let detailText: String?
    
    var body: some View {
        HStack(spacing: AppSpacing.small) {
            Circle()
                .fill(isActive ? Color.recordingActive : Color.recordingInactive)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: AppSpacing.minimal) {
                Text(isActive ? activeText : inactiveText)
                    .font(.statusText)
                    .fontWeight(.semibold)
                
                if let detailText = detailText {
                    Text(detailText)
                        .font(.statusDetail)
                        .foregroundColor(.secondaryText)
                }
            }
        }
    }
}

// MARK: - Error Message Component

struct AppErrorMessage: View {
    let message: String
    
    var body: some View {
        Text(message)
            .foregroundColor(.destructive)
            .padding(AppSpacing.medium)
            .background(Color.destructiveLight)
            .cornerRadius(12)
            .padding(AppSpacing.medium)
    }
}

// MARK: - Example Usage (for Previews or testing)

#if DEBUG
struct ComponentsPreview: View {
    @State private var isSelected = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sectionSpacing) {
                // Buttons
                Button("Primary Action") { }
                    .buttonStyle(PrimaryActionButtonStyle())

                Button("Secondary Action") { }
                    .buttonStyle(SecondaryActionButtonStyle())

                // Tab Button
                AppTabButton(
                    title: "Recorder",
                    iconName: AppIcons.tabRecorder,
                    isSelected: isSelected,
                    width: 80,
                    action: { isSelected.toggle() }
                )

                // Card
                StandardCard {
                    Text("This is content inside a standard card. It uses the defined card background, corner radius, and shadow.")
                        .appBody()
                }
                
                // Empty State
                AppEmptyState(
                    icon: AppIcons.noConversations,
                    title: "No conversations found",
                    subtitle: "Upload an audio file to get started"
                )
                
                // Loading State
                AppLoadingState(message: "Loading...")
                
                // Status Indicator
                AppStatusIndicator(
                    isActive: true,
                    activeText: "Recording",
                    inactiveText: "Ready",
                    detailText: "Speech detected"
                )
                
                // Error Message
                AppErrorMessage(message: "Something went wrong")
            }
            .padding(AppSpacing.medium)
        }
        .background(Color.primaryBackground)
    }
}

#Preview {
    ComponentsPreview()
}
#endif
