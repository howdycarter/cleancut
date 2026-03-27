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
            VStack(spacing: DS.Spacing.lg) {
                HStack {
                    Spacer()
                    Button("onb.skip") { done() }
                        .foregroundColor(.secondary)
                        .accessibilityLabel(Text("onb.skip.access"))
                }
                .padding(.horizontal, DS.Spacing.xl)

                TabView(selection: $index) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { (i, page) in
                        VStack(spacing: DS.Spacing.md) {
                            LogoView(size: 200)
                                .scaleEffect(index == i ? 1.0 : 0.85)
                                .opacity(index == i ? 1.0 : 0.6)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.2), value: index)
                            Text(localizedReplacingAppName(page.titleKey, appName: container.config.appName))
                                .appFont(.title2)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            Text(localizedReplacingAppName(page.subtitleKey, appName: container.config.appName))
                                .appFont(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, DS.Spacing.xl)
                        .padding(.vertical, DS.Spacing.lg)
                        .dsCard(radius: DS.Radius.lg)
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
                        .background(DS.primary)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        .shadow(color: DS.primary.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .accessibilityLabel(Text("onb.next.access"))
                .padding(.bottom, DS.Spacing.lg)
            }
            .padding(.vertical, DS.Spacing.xl)
        }
    }
}
