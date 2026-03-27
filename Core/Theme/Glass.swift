//
//  DSSurface.swift (replaces Glass.swift)
//
//  Surface styles: flat, bordered, elevated, glass, liquidGlass.
//  The active style is set in DesignSystem.swift via DS.surfaceStyle.
//

import SwiftUI

// MARK: - Surface Style Enum

public enum SurfaceStyle: String, Codable, Sendable, CaseIterable {
    case flat
    case bordered
    case elevated
    case glass
    case liquidGlass

    /// Backward compatibility: maps old "standard" raw value.
    public init(legacyRawValue: String) {
        switch legacyRawValue {
        case "standard": self = .elevated
        case "glass":    self = .glass
        default:         self = SurfaceStyle(rawValue: legacyRawValue) ?? .elevated
        }
    }
}

// MARK: - Surface Card Modifier

/// Applies the current surface style (from DS.surfaceStyle) to a view.
/// Use `.dsCard()` on any container to get automatic surface treatment.
public struct DSSurfaceModifier: ViewModifier {
    let style: SurfaceStyle
    let radius: CGFloat

    public init(style: SurfaceStyle = DS.surfaceStyle, radius: CGFloat = DS.Radius.md) {
        self.style = style
        self.radius = radius
    }

    public func body(content: Content) -> some View {
        switch style {
        case .flat:
            content
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))

        case .bordered:
            content
                .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(DS.Colors.border, lineWidth: DS.Border.thin)
                )

        case .elevated:
            content
                .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .shadow(color: DS.Shadow.md.color, radius: DS.Shadow.md.radius, x: DS.Shadow.md.x, y: DS.Shadow.md.y)

        case .glass:
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: DS.Border.thin)
                )
                .shadow(color: DS.Shadow.sm.color, radius: DS.Shadow.sm.radius, x: 0, y: DS.Shadow.sm.y)

        case .liquidGlass:
            // iOS 26+: Use Apple's native liquid glass API.
            // Pre-iOS 26: Falls back to ultra-thin material (same as .glass).
            //
            // When the iOS 26 SDK ships, uncomment the availability check:
            //   if #available(iOS 26, *) {
            //       content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius))
            //   } else { ... }
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: DS.Border.thin
                        )
                )
                .shadow(color: DS.Shadow.md.color, radius: DS.Shadow.md.radius, x: 0, y: DS.Shadow.md.y)
        }
    }
}

// MARK: - View Extensions

public extension View {

    /// Applies the global surface style from `DS.surfaceStyle`.
    func dsCard(radius: CGFloat = DS.Radius.md) -> some View {
        modifier(DSSurfaceModifier(style: DS.surfaceStyle, radius: radius))
    }

    /// Applies a specific surface style (overrides the global default).
    func dsCard(style: SurfaceStyle, radius: CGFloat = DS.Radius.md) -> some View {
        modifier(DSSurfaceModifier(style: style, radius: radius))
    }

    /// Backward compatibility: old glass card modifier.
    func glassCard(cornerRadius: CGFloat = DS.Radius.md, shadowOpacity: Double = 0.15) -> some View {
        modifier(DSSurfaceModifier(style: .glass, radius: cornerRadius))
    }
}

// MARK: - Conditional View Modifier Helper

public extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}
