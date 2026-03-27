//
//  Typography.swift
//
//  Centralized typography system.
//
//  Every text style in the app should go through `AppTypography` so that
//  swapping to a custom font is a single-file change in `FontRegistry.swift`.
//
//  Usage:
//    Text("Hello").font(AppTypography.title)
//    Text("Hello").appFont(.headline)
//

import SwiftUI

// MARK: - AppTypography

/// Static accessors for every standard text style, resolved through `FontRegistry`.
public enum AppTypography: Sendable {

    // MARK: Large Title
    public static var largeTitle: Font { FontRegistry.font(.bold, textStyle: .largeTitle) }

    // MARK: Titles
    public static var title: Font { FontRegistry.font(.bold, textStyle: .title) }
    public static var title2: Font { FontRegistry.font(.semibold, textStyle: .title2) }
    public static var title3: Font { FontRegistry.font(.semibold, textStyle: .title3) }

    // MARK: Heading / Body
    public static var headline: Font { FontRegistry.font(.semibold, textStyle: .headline) }
    public static var body: Font { FontRegistry.font(.regular, textStyle: .body) }
    public static var bodyBold: Font { FontRegistry.font(.bold, textStyle: .body) }

    // MARK: Supporting
    public static var callout: Font { FontRegistry.font(.regular, textStyle: .callout) }
    public static var subheadline: Font { FontRegistry.font(.regular, textStyle: .subheadline) }
    public static var footnote: Font { FontRegistry.font(.regular, textStyle: .footnote) }
    public static var footnoteSemibold: Font { FontRegistry.font(.semibold, textStyle: .footnote) }

    // MARK: Captions
    public static var caption: Font { FontRegistry.font(.regular, textStyle: .caption) }
    public static var captionBold: Font { FontRegistry.font(.bold, textStyle: .caption) }
    public static var caption2: Font { FontRegistry.font(.regular, textStyle: .caption2) }

    // MARK: Custom sizes

    /// Convenience for a custom point size with a specific weight.
    public static func custom(size: CGFloat, weight: FontFamily = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        FontRegistry.font(weight, size: size, relativeTo: style)
    }
}

// MARK: - AppTextStyle

/// Enum that mirrors the standard text styles so they can be passed as a
/// single value to the `.appFont(_:)` view modifier.
public enum AppTextStyle: Sendable {
    case largeTitle
    case title
    case title2
    case title3
    case headline
    case body
    case bodyBold
    case callout
    case subheadline
    case footnote
    case footnoteSemibold
    case caption
    case captionBold
    case caption2

    /// Resolves to the concrete `Font` via `AppTypography`.
    public var font: Font {
        switch self {
        case .largeTitle:       return AppTypography.largeTitle
        case .title:            return AppTypography.title
        case .title2:           return AppTypography.title2
        case .title3:           return AppTypography.title3
        case .headline:         return AppTypography.headline
        case .body:             return AppTypography.body
        case .bodyBold:         return AppTypography.bodyBold
        case .callout:          return AppTypography.callout
        case .subheadline:      return AppTypography.subheadline
        case .footnote:         return AppTypography.footnote
        case .footnoteSemibold: return AppTypography.footnoteSemibold
        case .caption:          return AppTypography.caption
        case .captionBold:      return AppTypography.captionBold
        case .caption2:         return AppTypography.caption2
        }
    }
}

// MARK: - View Modifier

/// Applies a font from the centralized typography system.
///
/// ```swift
/// Text("Welcome").appFont(.headline)
/// ```
public struct AppFontModifier: ViewModifier {
    public let style: AppTextStyle

    public func body(content: Content) -> some View {
        content.font(style.font)
    }
}

public extension View {
    /// Applies a centralized app font for the given text style.
    func appFont(_ style: AppTextStyle) -> some View {
        modifier(AppFontModifier(style: style))
    }
}
