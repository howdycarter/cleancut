//
//  MinimalOnboardingView.swift
//

import SwiftUI

struct MinimalOnboardingView: View {
    var done: () -> Void
    @Environment(\.appTheme) private var theme
    var body: some View {
        ZStack {
            AnimatedBackground().opacity(theme.isGlass ? 1 : 0.35)
            VStack(spacing: DesignTokens.Spacing.lg) {
                LogoView(size: 120)
                Text("onb.minimal.title")
                    .font(.title2.bold())
                Text("onb.minimal.subtitle")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.Spacing.xl)
                Button(action: done) {
                    Text("onb.getstarted")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DesignTokens.primaryColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                        .shadow(color: DesignTokens.primaryColor.opacity(0.3), radius: 12, x: 0, y: 6)
                }
            }
            .padding(.vertical, DesignTokens.Spacing.xl)
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .if(theme.isGlass) { view in view.glassCard(cornerRadius: DesignTokens.Radius.lg) }
        }
    }
}
