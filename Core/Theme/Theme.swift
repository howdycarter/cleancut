//
//  Theme.swift
//

import SwiftUI

public enum AppThemeStyle: String, Equatable, Sendable {
    case standard
    case glass
}

public struct AppTheme: Equatable, Sendable {
    public var primary: Color
    public var accent: Color
    public var style: AppThemeStyle

    public init(primary: Color = DesignTokens.primaryColor,
                accent: Color = DesignTokens.accentColor,
                style: AppThemeStyle = .standard) {
        self.primary = primary
        self.accent = accent
        self.style = style
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme()
}

public extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

public extension View {
    func appTheme(_ theme: AppTheme) -> some View { environment(\.appTheme, theme) }
}

public extension AppTheme {
    var isGlass: Bool { style == .glass }
}
