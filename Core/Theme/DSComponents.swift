//
//  DSComponents.swift
//
//  Reusable component styles that read from the design system.
//  Apply these to buttons, cards, and inputs for consistent styling.
//

import SwiftUI

// MARK: - Primary Button Style

/// Full-width accent-colored button. Use for primary CTAs.
///
/// ```swift
/// Button("Continue") { ... }
///     .buttonStyle(DSPrimaryButtonStyle())
/// ```
public struct DSPrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(.headline)
            .foregroundColor(DS.Colors.buttonPrimaryFg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .padding(.horizontal, DS.Spacing.lg)
            .background(DS.accent, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: DS.Motion.fast), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style

/// Outlined button. Use for secondary actions.
public struct DSSecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(.headline)
            .foregroundColor(DS.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .padding(.horizontal, DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(DS.accent, lineWidth: DS.Border.regular)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: DS.Motion.fast), value: configuration.isPressed)
    }
}

// MARK: - Ghost Button Style

/// Transparent button with text color only. Use for tertiary actions.
public struct DSGhostButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(.headline)
            .foregroundColor(DS.accent)
            .padding(.vertical, DS.Spacing.sm)
            .padding(.horizontal, DS.Spacing.md)
            .opacity(configuration.isPressed ? 0.5 : 1.0)
            .animation(.easeOut(duration: DS.Motion.fast), value: configuration.isPressed)
    }
}

// MARK: - Destructive Button Style

/// Red-tinted button for destructive actions.
public struct DSDestructiveButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .padding(.horizontal, DS.Spacing.lg)
            .background(DS.danger, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: DS.Motion.fast), value: configuration.isPressed)
    }
}

// MARK: - Card Modifier

/// Wraps content in a padded card with the current surface style.
///
/// ```swift
/// VStack { ... }
///     .dsCardContent()
/// ```
public struct DSCardContentModifier: ViewModifier {
    let padding: CGFloat
    let radius: CGFloat

    public init(padding: CGFloat = DS.Spacing.lg, radius: CGFloat = DS.Radius.lg) {
        self.padding = padding
        self.radius = radius
    }

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .dsCard(radius: radius)
    }
}

// MARK: - Input Modifier

/// Styled text field container matching the design system.
public struct DSInputModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .padding(DS.Spacing.md)
            .background(DS.Colors.surfaceSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(DS.Colors.border, lineWidth: DS.Border.thin)
            )
    }
}

// MARK: - View Extensions

public extension View {
    /// Wraps content in a padded card with the global surface style.
    func dsCardContent(padding: CGFloat = DS.Spacing.lg, radius: CGFloat = DS.Radius.lg) -> some View {
        modifier(DSCardContentModifier(padding: padding, radius: radius))
    }

    /// Applies design-system input styling to a text field.
    func dsInput() -> some View {
        modifier(DSInputModifier())
    }
}

// MARK: - Empty State View

/// Reusable empty state placeholder.
public struct DSEmptyState: View {
    public let title: String
    public let systemImage: String
    public var description: String? = nil

    public init(title: String, systemImage: String, description: String? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    public var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(DS.Colors.textTertiary)
            Text(title)
                .appFont(.headline)
                .foregroundColor(DS.Colors.textSecondary)
            if let description, !description.isEmpty {
                Text(description)
                    .appFont(.footnote)
                    .foregroundColor(DS.Colors.textTertiary)
            }
        }
        .padding(.vertical, DS.Spacing.xl)
        .frame(maxWidth: .infinity)
    }
}
