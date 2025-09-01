//
//  HighlightsOnboardingView.swift
//

import SwiftUI

struct HighlightsOnboardingView: View {
    let pages: [OnboardingPage]
    var done: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("onb.highlights.title")
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

            Button(action: done) {
                Text("onb.getstarted")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DesignTokens.primaryColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.xl)
    }
}
