//
//  DSColors.swift
//
//  Semantic color roles derived from DesignSystem.swift tokens.
//  These adapt automatically to light/dark mode.
//
//  You rarely need to edit this file — change the hex values in
//  DesignSystem.swift instead.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Semantic Color Roles

extension DS {

    /// Adaptive semantic colors that resolve from the neutral palette
    /// and automatically switch between light and dark mode.
    public enum Colors {

        // MARK: Backgrounds

        /// Main screen background.
        public static var background: Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? (UIColor(hex: DS.neutral900Hex) ?? .systemBackground)
                    : (UIColor(hex: DS.neutral50Hex) ?? .systemBackground)
            })
        }

        /// Card / elevated surface background.
        public static var surface: Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? (UIColor(hex: DS.neutral800Hex) ?? .secondarySystemBackground)
                    : .white
            })
        }

        /// Secondary surface (grouped content, inner cards).
        public static var surfaceSecondary: Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? (UIColor(hex: DS.neutral700Hex) ?? .tertiarySystemBackground)
                    : (UIColor(hex: DS.neutral100Hex) ?? .tertiarySystemBackground)
            })
        }

        // MARK: Text

        /// Primary text / headings.
        public static var textPrimary: Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? (UIColor(hex: DS.neutral50Hex) ?? .label)
                    : (UIColor(hex: DS.neutral900Hex) ?? .label)
            })
        }

        /// Secondary / supporting text.
        public static var textSecondary: Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? (UIColor(hex: DS.neutral400Hex) ?? .secondaryLabel)
                    : (UIColor(hex: DS.neutral500Hex) ?? .secondaryLabel)
            })
        }

        /// Tertiary / placeholder text.
        public static var textTertiary: Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? (UIColor(hex: DS.neutral600Hex) ?? .tertiaryLabel)
                    : (UIColor(hex: DS.neutral400Hex) ?? .tertiaryLabel)
            })
        }

        // MARK: Borders & Dividers

        public static var border: Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? (UIColor(hex: DS.neutral700Hex) ?? .separator)
                    : (UIColor(hex: DS.neutral200Hex) ?? .separator)
            })
        }

        public static var divider: Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? (UIColor(hex: DS.neutral800Hex) ?? .opaqueSeparator)
                    : (UIColor(hex: DS.neutral200Hex) ?? .opaqueSeparator)
            })
        }

        // MARK: Button Colors

        /// Primary button background (uses accent).
        public static var buttonPrimaryBg: Color { DS.accent }

        /// Primary button foreground. Auto-selects white or black for contrast.
        public static var buttonPrimaryFg: Color {
            contrastForeground(for: DS.accentHex)
        }

        /// Secondary / outline button.
        public static var buttonSecondaryBg: Color { .clear }
        public static var buttonSecondaryFg: Color { DS.accent }

        // MARK: Helpers

        /// Returns white or black depending on which provides better contrast
        /// against the given hex background.
        private static func contrastForeground(for hex: String) -> Color {
            guard let c = UIColor(hex: hex) else { return .white }
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            c.getRed(&r, green: &g, blue: &b, alpha: &a)
            let luminance = 0.299 * r + 0.587 * g + 0.114 * b
            return luminance > 0.5 ? .black : .white
        }
    }
}

// MARK: - Color(hex:) Extension

extension Color {
    public init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        let scanner = Scanner(string: hexString)
        var hexNumber: UInt64 = 0
        guard scanner.scanHexInt64(&hexNumber) else { return nil }
        let r, g, b, a: Double
        switch hexString.count {
        case 6:
            r = Double((hexNumber & 0xFF0000) >> 16) / 255
            g = Double((hexNumber & 0x00FF00) >> 8) / 255
            b = Double(hexNumber & 0x0000FF) / 255
            a = 1.0
        case 8:
            r = Double((hexNumber & 0xFF000000) >> 24) / 255
            g = Double((hexNumber & 0x00FF0000) >> 16) / 255
            b = Double((hexNumber & 0x0000FF00) >> 8) / 255
            a = Double(hexNumber & 0x000000FF) / 255
        default:
            return nil
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - UIColor(hex:) Extension

#if canImport(UIKit)
extension UIColor {
    public convenience init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        let scanner = Scanner(string: hexString)
        var hexNumber: UInt64 = 0
        guard scanner.scanHexInt64(&hexNumber) else { return nil }
        let r, g, b, a: CGFloat
        switch hexString.count {
        case 6:
            r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255
            g = CGFloat((hexNumber & 0x00FF00) >> 8) / 255
            b = CGFloat(hexNumber & 0x0000FF) / 255
            a = 1.0
        case 8:
            r = CGFloat((hexNumber & 0xFF000000) >> 24) / 255
            g = CGFloat((hexNumber & 0x00FF0000) >> 16) / 255
            b = CGFloat((hexNumber & 0x0000FF00) >> 8) / 255
            a = CGFloat(hexNumber & 0x000000FF) / 255
        default:
            return nil
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
#endif
