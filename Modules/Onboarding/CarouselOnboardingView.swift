//
//  CarouselOnboardingView.swift
//

import SwiftUI

struct CarouselOnboardingView: View {
    let pages: [OnboardingPage]
    var done: () -> Void
    @State private var index: Int = 0

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            TabView(selection: $index) {
                ForEach(Array(pages.enumerated()), id: \.offset) { (i, page) in
                    VStack(spacing: DesignTokens.Spacing.md) {
                        Image(systemName: page.systemImage)
                            .font(.system(size: 48))
                            .foregroundColor(DesignTokens.accentColor)
                            .padding(.bottom, DesignTokens.Spacing.md)
                        Text(LocalizedStringKey(page.titleKey))
                            .font(.title2.bold())
                        Text(LocalizedStringKey(page.subtitleKey))
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.xl)
                    .tag(i)
                }
            }
            .tabViewStyle(.page)

            Button(action: {
                if index < pages.count - 1 { index += 1 } else { done() }
            }) {
                Text(index < pages.count - 1 ? LocalizedStringKey("onb.next") : LocalizedStringKey("onb.getstarted"))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DesignTokens.primaryColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
            }
            .accessibilityLabel(Text("onb.next.access"))
        }
        .padding(.vertical, DesignTokens.Spacing.xl)
    }
}
