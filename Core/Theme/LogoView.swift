//
//  LogoView.swift
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct LogoView: View {
    var size: CGFloat = 96
    var animateLogo: Bool = true
    @State private var float: Bool = false
    @State private var glow: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(DS.primary.opacity(0.15))
                .frame(width: size * 1.2, height: size * 1.2)
                .scaleEffect(glow ? 1.05 : 0.95)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glow)

            // Prefer explicit AppLogo asset if provided; otherwise use the compiled App Icon if available,
            // and finally fall back to a friendly SF Symbol.
            Group {
                if let appLogo = (PlatformImage(named: "AppLogo") ?? appIconImage()) {
                    Image(platformImage: appLogo)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "app.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(DS.primary)
                        .padding(size * 0.2)
                }
            }
            .frame(width: size, height: size)
            .shadow(color: DS.accent.opacity(0.4), radius: 12, x: 0, y: 4)
            .offset(y: animateLogo ? (float ? -6 : 6) : 0)
            .scaleEffect(1.0)
            .animation(animateLogo ? .easeInOut(duration: 2.0).repeatForever(autoreverses: true) : nil, value: float)
        }
        .onAppear { float = true; glow = true }
        .accessibilityHidden(true)
    }
}

// MARK: - Platform helpers

#if canImport(UIKit)
private typealias PlatformImage = UIImage
#else
import AppKit
private typealias PlatformImage = NSImage
#endif

private extension Image {
    init(platformImage: PlatformImage) {
        #if canImport(UIKit)
        self = Image(uiImage: platformImage)
        #else
        self = Image(nsImage: platformImage)
        #endif
    }
}

// Attempts to load the compiled app icon image from Info.plist metadata (iOS).
private func appIconImage() -> PlatformImage? {
    #if canImport(UIKit)
    guard
        let info = Bundle.main.infoDictionary,
        let icons = info["CFBundleIcons"] as? [String: Any],
        let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
        let files = primary["CFBundleIconFiles"] as? [String],
        let name = files.last
    else { return nil }
    return UIImage(named: name)
    #else
    return nil
    #endif
}

// Add an AppLogo image in Assets.xcassets to override the fallback symbol.
