//
//  DesignSystem.swift
//
//  THE ONE FILE — Edit values here to change the entire app's look and feel.
//
//  How it works:
//  1. Change hex values, spacing, radius, etc. below
//  2. Build and run — the entire app updates
//  3. No other file needs editing for basic theming
//
//  Preset reference (copy values you like):
//
//    Minimal:   primaryHex "#1F2937", accentHex "#3B82F6", surfaceStyle .bordered
//    Bold:      primaryHex "#7C3AED", accentHex "#F97316", surfaceStyle .elevated
//    Wellness:  primaryHex "#10B981", accentHex "#F59E0B", surfaceStyle .elevated, spacingDensity 1.1
//    Glass:     primaryHex "#6366F1", accentHex "#EC4899", surfaceStyle .glass
//    Dark:      primaryHex "#A78BFA", accentHex "#34D399", surfaceStyle .elevated
//

import SwiftUI

// MARK: - DS (Design System)

public enum DS {

    // =================================================================
    // BRAND COLORS
    // Your app's identity. Change these two to rebrand instantly.
    // =================================================================

    public static let primaryHex: String = "__PRIMARY_COLOR__"
    public static let accentHex: String  = "__ACCENT_COLOR__"

    // =================================================================
    // NEUTRAL PALETTE
    // Used for backgrounds, text, borders, dividers.
    // Adjust for a warmer or cooler feel.
    // =================================================================

    public static let neutral50Hex  = "#FAFAFA"
    public static let neutral100Hex = "#F5F5F5"
    public static let neutral200Hex = "#E5E5E5"
    public static let neutral300Hex = "#D4D4D4"
    public static let neutral400Hex = "#A3A3A3"
    public static let neutral500Hex = "#737373"
    public static let neutral600Hex = "#525252"
    public static let neutral700Hex = "#404040"
    public static let neutral800Hex = "#262626"
    public static let neutral900Hex = "#171717"

    // =================================================================
    // FEEDBACK COLORS
    // Used for success, warning, danger, and info states.
    // =================================================================

    public static let successHex = "#22C55E"
    public static let warningHex = "#F59E0B"
    public static let dangerHex  = "#EF4444"
    public static let infoHex    = "#3B82F6"

    // =================================================================
    // SURFACE STYLE
    // Controls how cards, sheets, and containers look globally.
    //
    //   .flat         — Clean, no background treatment
    //   .bordered     — Subtle border, no fill
    //   .elevated     — Shadow-based depth
    //   .glass        — Frosted blur material (iOS 16+)
    //   .liquidGlass  — Apple Liquid Glass (iOS 26+, falls back to .glass)
    // =================================================================

    public static let surfaceStyle: SurfaceStyle = .elevated

    // =================================================================
    // SPACING DENSITY
    // Multiplier applied to all spacing values.
    //   0.85 = compact | 1.0 = standard | 1.15 = roomy
    // =================================================================

    public static let spacingDensity: CGFloat = 1.0

    // =================================================================
    // SPACING SCALE
    // =================================================================

    public enum Spacing {
        public static var xs:   CGFloat { 4 * DS.spacingDensity }
        public static var sm:   CGFloat { 8 * DS.spacingDensity }
        public static var md:   CGFloat { 12 * DS.spacingDensity }
        public static var lg:   CGFloat { 16 * DS.spacingDensity }
        public static var xl:   CGFloat { 24 * DS.spacingDensity }
        public static var xxl:  CGFloat { 32 * DS.spacingDensity }
        public static var xxxl: CGFloat { 48 * DS.spacingDensity }
    }

    // =================================================================
    // RADIUS SCALE
    // Controls corner roundness globally.
    // =================================================================

    public enum Radius {
        public static let none: CGFloat = 0
        public static let xs:   CGFloat = 4
        public static let sm:   CGFloat = 8
        public static let md:   CGFloat = 12
        public static let lg:   CGFloat = 20
        public static let xl:   CGFloat = 28
        public static let xxl:  CGFloat = 36
        public static let full: CGFloat = 9999   // Pill / capsule shape
    }

    // =================================================================
    // SHADOW SCALE
    // =================================================================

    public struct ShadowToken: Equatable, Sendable {
        public let color: Color
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat
    }

    public enum Shadow {
        public static let none = ShadowToken(color: .clear, radius: 0, x: 0, y: 0)
        public static let sm   = ShadowToken(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        public static let md   = ShadowToken(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        public static let lg   = ShadowToken(color: Color.black.opacity(0.15), radius: 16, x: 0, y: 8)
        public static let xl   = ShadowToken(color: Color.black.opacity(0.2), radius: 24, x: 0, y: 12)
    }

    // =================================================================
    // MOTION
    // Animation durations and spring configs.
    //   Shorter = snappier. Longer = smoother.
    // =================================================================

    public enum Motion {
        public static let fast:           Double = 0.15
        public static let normal:         Double = 0.25
        public static let slow:           Double = 0.4
        public static let springDamping:  Double = 0.8
        public static let springResponse: Double = 0.35

        public static var spring: Animation {
            .spring(response: springResponse, dampingFraction: springDamping)
        }
    }

    // =================================================================
    // BORDER
    // =================================================================

    public enum Border {
        public static let thin:    CGFloat = 0.5
        public static let regular: CGFloat = 1.0
        public static let thick:   CGFloat = 2.0
    }

    // =================================================================
    // RESOLVED BRAND COLORS
    // Computed from hex values above. Use these in code.
    // =================================================================

    public static var primary: Color { Color(hex: primaryHex) ?? .purple }
    public static var accent:  Color { Color(hex: accentHex) ?? .orange }

    public static var success: Color { Color(hex: successHex) ?? .green }
    public static var warning: Color { Color(hex: warningHex) ?? .yellow }
    public static var danger:  Color { Color(hex: dangerHex) ?? .red }
    public static var info:    Color { Color(hex: infoHex) ?? .blue }

    // Neutral scale (resolved)
    public static var neutral50:  Color { Color(hex: neutral50Hex) ?? Color(.systemBackground) }
    public static var neutral100: Color { Color(hex: neutral100Hex) ?? Color(.secondarySystemBackground) }
    public static var neutral200: Color { Color(hex: neutral200Hex) ?? Color(.tertiarySystemBackground) }
    public static var neutral300: Color { Color(hex: neutral300Hex) ?? Color(.systemGray4) }
    public static var neutral400: Color { Color(hex: neutral400Hex) ?? Color(.systemGray3) }
    public static var neutral500: Color { Color(hex: neutral500Hex) ?? Color(.systemGray2) }
    public static var neutral600: Color { Color(hex: neutral600Hex) ?? Color(.systemGray) }
    public static var neutral700: Color { Color(hex: neutral700Hex) ?? Color(.darkGray) }
    public static var neutral800: Color { Color(hex: neutral800Hex) ?? Color(.darkGray) }
    public static var neutral900: Color { Color(hex: neutral900Hex) ?? Color(.black) }

    // =================================================================
    // BACKWARD COMPATIBILITY
    // Existing code using DesignTokens.primaryColor etc. still works.
    // =================================================================

    public static var primaryColor: Color { primary }
    public static var accentColor: Color { accent }
}

// Allow existing code that references `DesignTokens` to keep working.
public typealias DesignTokens = DS
