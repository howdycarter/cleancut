//
//  HomeView.swift
//

import SwiftUI

struct HomeView: View {
    @Environment(\.container) private var container
    @EnvironmentObject private var router: AppRouter
    @Environment(\.appTheme) private var theme
    @StateObject private var vm = HomeViewModel()
    @State private var isShowingShowcase: Bool = false
    @State private var profile: Profile?

    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.md), count: 2) }

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            Text("Everything Set! Start Building!")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.lg)
            Spacer(minLength: 0)
        }
    }
}

private struct HomeCell: View {
    let item: HomeViewModel.Item
    @Environment(\.appTheme) private var theme
    var body: some View {
        Text(item.title)
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 80)
            .padding(DesignTokens.Spacing.md)
            .foregroundColor(theme.isGlass ? .primary : DesignTokens.primaryColor)
            .background(
                Group {
                    if theme.isGlass {
                        Color.clear
                    } else {
                        DesignTokens.primaryColor.opacity(0.08)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
            .if(theme.isGlass) { view in
                view.glassCard(cornerRadius: DesignTokens.Radius.md)
            }
            .accessibilityLabel(Text("home.item.access"))
    }
}

// Subscription management via StoreKit removed. Status still displays in ProfileSummary.

private struct ProfileSummary: View {
    let profile: Profile
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            if let url = profile.avatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure(_): Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundColor(.secondary)
                    case .empty: ProgressView()
                    @unknown default: EmptyView()
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundColor(.secondary)
                    .frame(width: 56, height: 56)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name.isEmpty ? "" : profile.name).font(.headline)
                if !profile.contact.isEmpty { Text(profile.contact).foregroundColor(.secondary) }
                Text(profile.subscriptionStatus.rawValue)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
        .accessibilityElement(children: .combine)
    }
}

private struct HeaderCard: View {
    let profile: Profile?
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(DesignTokens.primaryColor.opacity(0.08))
            HStack(spacing: 16) {
                LogoView(size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    if let p = profile, !p.name.isEmpty {
                        Text("Welcome, \(p.name)").font(.headline)
                        if !p.contact.isEmpty { Text(p.contact).foregroundColor(.secondary) }
                        Text(p.subscriptionStatus.rawValue)
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Welcome").font(.headline)
                        Text("Let’s build something great.").foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(16)
        }
        .accessibilityElement(children: .combine)
    }
}

 
