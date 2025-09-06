//
//  LogoView.swift
//

import SwiftUI

struct LogoView: View {
    var size: CGFloat = 96
    var animateLogo: Bool = true
    @State private var float: Bool = false
    @State private var glow: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(DesignTokens.primaryColor.opacity(0.15))
                .frame(width: size * 1.2, height: size * 1.2)
                .scaleEffect(glow ? 1.05 : 0.95)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glow)

            // Prefer explicit AppLogo asset if provided; otherwise show a symbol.
            Group {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
            }
            .frame(width: size, height: size)
            .shadow(color: DesignTokens.accentColor.opacity(0.4), radius: 12, x: 0, y: 4)
            .offset(y: animateLogo ? (float ? -6 : 6) : 0)
            .scaleEffect(1.0)
            .animation(animateLogo ? .easeInOut(duration: 2.0).repeatForever(autoreverses: true) : nil, value: float)
        }
        .onAppear { float = true; glow = true }
        .accessibilityHidden(true)
    }
}

// No UIKit usage: assumes an "AppLogo" asset exists
