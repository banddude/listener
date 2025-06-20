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
            .padding(16)
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
            .padding(16)
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
        if width < 70 || title.count > 8 {
            return .tabButtonSmall
        } else if width < 80 {
            return .tabButtonMedium
        } else {
            return .tabButtonLarge
        }
    }
    
    private var iconSize: CGFloat {
        width < 70 ? 12 : 14
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: iconName)
                    .font(.system(size: iconSize))
                Text(title)
                    .font(fontSize)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundColor(isSelected ? .tabSelected : .tabUnselected)
            .frame(width: width, height: 50)
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
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .standardShadow()
    }
}

// MARK: - Layout Templates

struct AppScrollContainer<Content: View>: View {
    let content: Content
    let spacing: CGFloat
    
    init(spacing: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                content
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct AppSectionHeader: View {
    let title: String
    let subtitle: String?
    let actionIcon: String?
    let actionColor: Color
    let action: (() -> Void)?
    
    init(title: String, subtitle: String? = nil, actionIcon: String? = nil, actionColor: Color = .accent, action: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.actionIcon = actionIcon
        self.actionColor = actionColor
        self.action = action
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .appHeadline()
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .appCaption()
                        .foregroundColor(.secondaryText)
                }
            }
            
            Spacer()
            
            if let actionIcon = actionIcon, let action = action {
                Button(action: action) {
                    Image(systemName: actionIcon)
                        .foregroundColor(actionColor)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct AppMainVStack<Content: View>: View {
    let spacing: CGFloat
    let content: Content
    
    init(spacing: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
    }
}

// MARK: - Empty State Component

struct AppEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
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
        .padding(.vertical, 40)
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
        .padding(16)
    }
}

// MARK: - Status Indicator Component

struct AppStatusIndicator: View {
    let isActive: Bool
    let activeText: String
    let inactiveText: String
    let detailText: String?
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isActive ? Color.recordingActive : Color.recordingInactive)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
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

// MARK: - Speaker Avatar Component

struct AppSpeakerAvatar: View {
    let speakerName: String?
    let size: CGFloat
    
    init(speakerName: String?, size: CGFloat = 40) {
        self.speakerName = speakerName
        self.size = size
    }
    
    var body: some View {
        Circle()
            .fill(avatarBackgroundColor)
            .frame(width: size, height: size)
            .overlay(
                Text(avatarInitials)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(.white)
            )
    }
    
    private var avatarInitials: String {
        guard let name = speakerName, !name.isEmpty else {
            return "?"
        }
        
        let components = name.split(separator: " ")
        if components.count >= 2 {
            let firstInitial = String(components[0].first ?? "?")
            let lastInitial = String(components[1].first ?? "?")
            return (firstInitial + lastInitial).uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
    
    private var avatarBackgroundColor: Color {
        guard let name = speakerName else {
            return .gray
        }
        
        // Generate consistent color based on name hash
        let hash = name.hashValue
        let colors: [Color] = [.blue, .green, .orange, .purple, .red, .pink, .indigo, .teal]
        return colors[abs(hash) % colors.count]
    }
}

// MARK: - Info Card Component

struct AppInfoCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            content
        }
        .padding(AppSpacing.medium)
        .background(Color.lightGrayBackground)
        .cornerRadius(12)
    }
}

// MARK: - Icon Button Component

struct AppIconButton: View {
    let iconName: String
    let size: CGFloat
    let backgroundColor: Color
    let foregroundColor: Color
    let action: () -> Void
    
    init(
        iconName: String,
        size: CGFloat = 36,
        backgroundColor: Color = .accent,
        foregroundColor: Color = .white,
        action: @escaping () -> Void
    ) {
        self.iconName = iconName
        self.size = size
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundColor(foregroundColor)
                .frame(width: size, height: size)
                .background(backgroundColor)
                .clipShape(Circle())
        }
    }
}

// MARK: - Form Card Component

struct AppFormCard<Content: View>: View {
    let title: String?
    let content: Content
    
    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            if let title = title {
                Text(title)
                    .appSubtitle()
                    .foregroundColor(.primaryText)
            }
            
            content
        }
        .padding(AppSpacing.medium)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Status Badge Component

struct AppStatusBadge: View {
    let text: String
    let style: BadgeStyle
    
    enum BadgeStyle {
        case success
        case warning
        case destructive
        case info
        case neutral
        
        var backgroundColor: Color {
            switch self {
            case .success: return .success.opacity(0.1)
            case .warning: return .warning.opacity(0.1)
            case .destructive: return .destructive.opacity(0.1)
            case .info: return .accent.opacity(0.1)
            case .neutral: return .lightGrayBackground
            }
        }
        
        var textColor: Color {
            switch self {
            case .success: return .success
            case .warning: return .warning
            case .destructive: return .destructive
            case .info: return .accent
            case .neutral: return .secondaryText
            }
        }
    }
    
    var body: some View {
        Text(text)
            .appCaption()
            .foregroundColor(style.textColor)
            .padding(.horizontal, AppSpacing.small)
            .padding(.vertical, AppSpacing.extraSmall)
            .background(style.backgroundColor)
            .cornerRadius(8)
    }
}

// MARK: - Error Message Component

struct AppErrorMessage: View {
    let message: String
    
    var body: some View {
        Text(message)
            .foregroundColor(.destructive)
            .padding(16)
            .background(Color.destructiveLight)
            .cornerRadius(12)
            .padding(16)
    }
}

// MARK: - Statistics Component

struct StatItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accent)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Example Usage (for Previews or testing)

#if DEBUG
struct ComponentsPreview: View {
    @State private var isSelected = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
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
                    width: 80
                ) { isSelected.toggle() }

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
                
                // Info Card
                AppInfoCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Info Card Example")
                            .appSubtitle()
                        Text("This is content inside an info card with consistent styling.")
                            .appCaption()
                    }
                }
                
                // Icon Buttons
                HStack(spacing: 12) {
                    AppIconButton(iconName: "play.fill") {}
                    AppIconButton(iconName: "pencil", backgroundColor: .success) {}
                    AppIconButton(iconName: "trash", backgroundColor: .destructive) {}
                }
                
                // Form Card
                AppFormCard(title: "Form Section") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .appCaption()
                        Text("Sample form content goes here")
                            .appBody()
                    }
                }
                
                // Status Badges
                HStack(spacing: 8) {
                    AppStatusBadge(text: "Success", style: .success)
                    AppStatusBadge(text: "Warning", style: .warning)
                    AppStatusBadge(text: "Error", style: .destructive)
                    AppStatusBadge(text: "Info", style: .info)
                }
                
                // Error Message
                AppErrorMessage(message: "Something went wrong")
            }
            .padding(16)
        }
        .background(Color.primaryBackground)
    }
}

#Preview {
    ComponentsPreview()
}
#endif
