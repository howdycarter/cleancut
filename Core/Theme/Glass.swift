//
//  Glass.swift
//

import SwiftUI

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var shadowOpacity: Double = 0.15
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(shadowOpacity), radius: 16, x: 0, y: 8)
    }
}

public extension View {
    func glassCard(cornerRadius: CGFloat = DesignTokens.Radius.md, shadowOpacity: Double = 0.15) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, shadowOpacity: shadowOpacity))
    }
}

// Conditional view modifier helper available app-wide.
public extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}
