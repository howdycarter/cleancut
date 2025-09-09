//
//  CarouselOnboardingView.swift
//

import SwiftUI

struct CarouselOnboardingView: View {
    let pages: [OnboardingPage]
    var done: () -> Void
    @State private var index: Int = 0
    @Environment(\.appTheme) private var theme
    @Environment(\.container) private var container

    var body: some View {
        ZStack {
            AnimatedBackground().opacity(theme.isGlass ? 1 : 0.35)
            VStack(spacing: DesignTokens.Spacing.lg) {
                HStack {
                    Spacer()
                    Button("onb.skip") { done() }
                        .foregroundColor(.secondary)
                        .accessibilityLabel(Text("onb.skip.access"))
                }
                .padding(.horizontal, DesignTokens.Spacing.xl)

                TabView(selection: $index) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { (i, page) in
                        VStack(spacing: DesignTokens.Spacing.md) {
                            LogoView(size: 200)
                                .scaleEffect(index == i ? 1.0 : 0.85)
                                .opacity(index == i ? 1.0 : 0.6)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.2), value: index)
                            Text(localizedReplacingAppName(page.titleKey, appName: container.config.appName))
                                .font(.title2.bold())
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            Text(localizedReplacingAppName(page.subtitleKey, appName: container.config.appName))
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, DesignTokens.Spacing.xl)
                        .padding(.vertical, DesignTokens.Spacing.lg)
                        .background(
                            Group {
                                if theme.isGlass { Color.clear } else { Color.clear }
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
                        .if(theme.isGlass) { view in view.glassCard(cornerRadius: DesignTokens.Radius.lg) }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))

                Button(action: {
                    if index < pages.count - 1 {
                        withAnimation(.easeInOut(duration: 0.35)) { index += 1 }
                    } else {
                        withAnimation(.easeInOut(duration: 0.35)) { done() }
                    }
                }) {
                    Text(index < pages.count - 1 ? LocalizedStringKey("onb.next") : LocalizedStringKey("onb.getstarted"))
                        .frame(maxWidth: 320)
                        .padding()
                        .background(DesignTokens.primaryColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                        .shadow(color: DesignTokens.primaryColor.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .accessibilityLabel(Text("onb.next.access"))
                .padding(.bottom, DesignTokens.Spacing.lg)
            }
            .padding(.vertical, DesignTokens.Spacing.xl)
        }
    }
}
