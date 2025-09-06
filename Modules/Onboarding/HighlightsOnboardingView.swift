//
//  HighlightsOnboardingView.swift
//

import SwiftUI

struct HighlightsOnboardingView: View {
    let pages: [OnboardingPage]
    var done: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            AnimatedBackground().opacity(theme.isGlass ? 1 : 0.35)
            VStack(spacing: DesignTokens.Spacing.xl) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    HStack(spacing: 12) {
                        LogoView(size: 48)
                        Text("onb.highlights.title")
                    }
                        .font(.largeTitle.bold())
                    Text("onb.highlights.subtitle")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: DesignTokens.Spacing.lg) {
                    ForEach(pages) { page in
                        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                            Image(systemName: page.systemImage)
                                .foregroundColor(DesignTokens.accentColor)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(LocalizedStringKey(page.titleKey)).font(.headline)
                                Text(LocalizedStringKey(page.subtitleKey)).foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(DesignTokens.Spacing.lg)
                .if(theme.isGlass) { view in view.glassCard(cornerRadius: DesignTokens.Radius.lg) }

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
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.vertical, DesignTokens.Spacing.xl)
        }
    }
}
