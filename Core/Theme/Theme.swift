//
//  DSEnvironment.swift (replaces Theme.swift)
//
//  Theme environment injection for SwiftUI views.
//

import SwiftUI

// MARK: - DSTheme

public struct DSTheme: Equatable, Sendable {
    public var surfaceStyle: SurfaceStyle

    public init(surfaceStyle: SurfaceStyle = DS.surfaceStyle) {
        self.surfaceStyle = surfaceStyle
    }

    /// Backward compatibility: init with `style:` parameter name.
    public init(style: SurfaceStyle) {
        self.surfaceStyle = style
    }

    /// Whether the current surface style uses translucent materials.
    public var isGlass: Bool {
        surfaceStyle == .glass || surfaceStyle == .liquidGlass
    }
}

// Backward compatibility typealiases
public typealias AppTheme = DSTheme
public typealias AppThemeStyle = SurfaceStyle

// Allow old code that stored "standard" or "glass" in AppStorage to still work.
extension SurfaceStyle {
    /// Maps legacy "standard" to the current default surface style.
    public static var standard: SurfaceStyle { .elevated }
}

// MARK: - Environment Key

private struct DSThemeKey: EnvironmentKey {
    static let defaultValue = DSTheme()
}

public extension EnvironmentValues {
    var dsTheme: DSTheme {
        get { self[DSThemeKey.self] }
        set { self[DSThemeKey.self] = newValue }
    }

    /// Backward compatibility: `appTheme` maps to `dsTheme`.
    var appTheme: DSTheme {
        get { self[DSThemeKey.self] }
        set { self[DSThemeKey.self] = newValue }
    }
}

// MARK: - View Extensions

public extension View {
    func dsTheme(_ theme: DSTheme) -> some View {
        environment(\.dsTheme, theme)
    }

    /// Backward compatibility.
    func appTheme(_ theme: DSTheme) -> some View {
        environment(\.dsTheme, theme)
    }
}
