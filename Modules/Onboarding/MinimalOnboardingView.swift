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
            VStack(spacing: DS.Spacing.lg) {
                LogoView(size: 120)
                Text("onb.minimal.title")
                    .appFont(.title2)
                Text("onb.minimal.subtitle")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)
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
            .padding(.vertical, DS.Spacing.xl)
            .padding(.horizontal, DS.Spacing.xl)
            .dsCard(radius: DS.Radius.lg)
        }
    }
}
