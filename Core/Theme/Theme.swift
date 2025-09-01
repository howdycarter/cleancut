//
//  Theme.swift
//

import SwiftUI

public struct AppTheme: Equatable, Sendable {
    public var primary: Color
    public var accent: Color

    public init(primary: Color = DesignTokens.primaryColor,
                accent: Color = DesignTokens.accentColor) {
        self.primary = primary
        self.accent = accent
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
