//
//  FontRegistry.swift
//
//  Central font registry -- change fonts in ONE place.
//
//  HOW TO USE CUSTOM FONTS:
//  1. Add your .ttf or .otf files to Resources/Fonts/
//  2. Add font file names to Info.plist under "Fonts provided by application"
//     (UIAppFonts), e.g. ["Poppins-Regular.ttf", "Poppins-Bold.ttf"]
//  3. Update the `FontFamily` cases below with each weight's PostScript name.
//     Tip: Run `FontRegistry.logAvailableFonts()` once to print every installed
//     PostScript name to the console.
//  4. That's it -- the entire app updates automatically.
//
//  To revert to the system font (SF Pro) simply leave every raw value as ""
//  (the default).
//

import SwiftUI

// MARK: - FontFamily

/// Maps semantic weights to PostScript font names.
///
/// Set the raw value to a font's PostScript name to activate it app-wide.
/// Leave raw values empty (`""`) to use the platform system font.
///
/// Example (Poppins):
/// ```
/// case regular  = "Poppins-Regular"
/// case medium   = "Poppins-Medium"
/// case semibold = "Poppins-SemiBold"
/// case bold     = "Poppins-Bold"
/// ```
public enum FontFamily: Sendable, CaseIterable {
    case regular
    case medium
    case semibold
    case bold

    /// The PostScript name for this weight.
    /// Leave empty (`""`) to use the platform system font.
    ///
    /// Example (Poppins):
    /// ```
    /// case .regular:  return "Poppins-Regular"
    /// case .medium:   return "Poppins-Medium"
    /// case .semibold: return "Poppins-SemiBold"
    /// case .bold:     return "Poppins-Bold"
    /// ```
    public var postScriptName: String {
        switch self {
        case .regular:  return ""
        case .medium:   return ""
        case .semibold: return ""
        case .bold:     return ""
        }
    }

    /// `true` when every weight resolves to the system font.
    public static var isSystemFont: Bool {
        allCases.allSatisfy { $0.postScriptName.isEmpty }
    }
}

// MARK: - FontRegistry

/// Resolves `FontFamily` + size into a concrete `Font`, respecting Dynamic Type.
public enum FontRegistry: Sendable {

    /// Returns a `Font` for the given family weight and point size.
    ///
    /// When a custom PostScript name is configured, the font is created via
    /// `Font.custom(_:size:relativeTo:)` so iOS still scales the size for the
    /// user's Dynamic Type setting. When the name is empty the equivalent
    /// system font is returned instead.
    public static func font(_ family: FontFamily, size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        if family.postScriptName.isEmpty {
            return .system(size: size, weight: family.systemWeight)
        }
        return .custom(family.postScriptName, size: size, relativeTo: textStyle)
    }

    /// Returns a system-design `Font` sized to a `Font.TextStyle`, using the
    /// custom family when configured.
    public static func font(_ family: FontFamily, textStyle: Font.TextStyle) -> Font {
        if family.postScriptName.isEmpty {
            return Font.system(textStyle).weight(family.systemWeight)
        }
        return .custom(family.postScriptName, size: pointSize(for: textStyle), relativeTo: textStyle)
    }

    // MARK: Debugging

    /// Prints every installed font family + PostScript name to the console.
    /// Call once from `onAppear` or `init` to discover the correct names.
    #if canImport(UIKit)
    public static func logAvailableFonts() {
        for family in UIFont.familyNames.sorted() {
            print("Family: \(family)")
            for name in UIFont.fontNames(forFamilyName: family) {
                print("  - \(name)")
            }
        }
    }
    #endif
}

// MARK: - Internal Helpers

extension FontRegistry {

    /// Default Apple HIG point sizes for each text style (at the Large
    /// Dynamic Type setting). These are used as the *base* size when mapping
    /// a custom font to a text style so that `relativeTo:` can scale
    /// proportionally.
    static func pointSize(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle:  return 34
        case .title:       return 28
        case .title2:      return 22
        case .title3:      return 20
        case .headline:    return 17
        case .body:        return 17
        case .callout:     return 16
        case .subheadline: return 15
        case .footnote:    return 13
        case .caption:     return 12
        case .caption2:    return 11
        @unknown default:  return 17
        }
    }
}

private extension FontFamily {
    /// Maps the semantic family weight to a SwiftUI `Font.Weight` for system
    /// font fallback.
    var systemWeight: Font.Weight {
        switch self {
        case .regular:  return .regular
        case .medium:   return .medium
        case .semibold: return .semibold
        case .bold:     return .bold
        }
    }
}
