//
//  MinimalOnboardingView.swift
//

import SwiftUI

struct MinimalOnboardingView: View {
    var done: () -> Void
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "app.gift")
                .font(.system(size: 56))
                .foregroundColor(DesignTokens.accentColor)
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
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xl)
    }
}
