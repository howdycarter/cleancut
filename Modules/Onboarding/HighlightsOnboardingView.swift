//
//  HighlightsOnboardingView.swift
//

import SwiftUI

struct HighlightsOnboardingView: View {
    let pages: [OnboardingPage]
    var done: () -> Void
    @Environment(\.appTheme) private var theme
    @Environment(\.container) private var container

    var body: some View {
        ZStack {
            AnimatedBackground().opacity(theme.isGlass ? 1 : 0.35)
            VStack(spacing: DS.Spacing.xl) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack(spacing: 12) {
                        LogoView(size: 48)
                        Text("onb.highlights.title")
                    }
                        .appFont(.largeTitle)
                    Text("onb.highlights.subtitle")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: DS.Spacing.lg) {
                    ForEach(pages) { page in
                        HStack(alignment: .top, spacing: DS.Spacing.md) {
                            Image(systemName: page.systemImage)
                                .foregroundColor(DS.accent)
                                .appFont(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(localizedReplacingAppName(page.titleKey, appName: container.config.appName)).appFont(.headline)
                                Text(localizedReplacingAppName(page.subtitleKey, appName: container.config.appName)).foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(DS.Spacing.lg)
                .dsCard(radius: DS.Radius.lg)

                Button(action: { withAnimation(.easeInOut(duration: 0.35)) { done() } }) {
                    Text("onb.getstarted")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DS.primary)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        .shadow(color: DS.primary.opacity(0.3), radius: 12, x: 0, y: 6)
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.xl)
        }
    }
}
