//
//  HomeView.swift
//
//  Neutral, configurable home screen shell.
//  Add your own feature sections below. Sections are gated by feature flags.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct HomeView: View {
    @Environment(\.container) private var container
    @EnvironmentObject private var router: AppRouter
    @State private var profile: Profile?

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                // Welcome header
                HeaderCard(profile: profile)

                // ─────────────────────────────────────────────
                // FEATURE SECTIONS
                // Add your own sections here. Each section is
                // gated by its feature flag so it disappears
                // when disabled.
                // ─────────────────────────────────────────────

                if container.config.featureFlags.aiFeatures {
                    HomeSection(
                        title: String(localized: "home.section.ai"),
                        items: [
                            .init(title: String(localized: "home.ai.chat"), icon: "text.bubble.fill", route: .aiChat),
                            .init(title: String(localized: "home.ai.images"), icon: "photo.on.rectangle", route: .aiImages),
                            .init(title: String(localized: "home.ai.vision"), icon: "viewfinder", route: .aiVision),
                        ]
                    )
                }

                // Example: add your own section
                // HomeSection(title: "My Features", items: [
                //     .init(title: "Dashboard", icon: "chart.bar.fill", route: .home),
                // ])

                // Getting started (shown when no feature sections are active)
                if !hasActiveSections {
                    GettingStartedCard()
                }
            }
            .padding(DS.Spacing.lg)
        }
        .task { await loadProfile() }
    }

    private var hasActiveSections: Bool {
        container.config.featureFlags.aiFeatures
    }

    private func loadProfile() async {
        guard container.config.featureFlags.auth else { return }
        if let user = await container.authRepository.currentUser() {
            do { profile = try await container.profileRepository.fetchProfile(for: user.id) }
            catch { profile = nil }
        }
    }
}

// MARK: - Home Section (Reusable)

/// A titled grid of menu buttons. Use this to add feature sections to the home screen.
///
/// ```swift
/// HomeSection(title: "Tools", items: [
///     .init(title: "Scanner", icon: "qrcode", route: .detail(id: "scan")),
/// ])
/// ```
struct HomeSection: View {
    struct MenuItem: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let route: AppRoute
    }

    let title: String
    let items: [MenuItem]
    @EnvironmentObject private var router: AppRouter

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.md), count: 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(title)
                .appFont(.headline)
            LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
                ForEach(items) { item in
                    HomeMenuButton(title: item.title, systemImage: item.icon) {
                        router.push(item.route)
                    }
                }
            }
        }
    }
}

// MARK: - Home Menu Button

private struct HomeMenuButton: View {
    let title: String
    let systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(DS.accent)
                Text(title)
                    .appFont(.headline)
                    .foregroundColor(DS.Colors.textPrimary)
                Spacer()
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 72)
            .dsCard(radius: DS.Radius.md)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Header Card

private struct HeaderCard: View {
    let profile: Profile?

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: DS.Spacing.lg) {
                LogoView(size: 56)
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    if let p = profile, !p.name.isEmpty {
                        Text(String(localized: "home.welcome.named \(p.name)"))
                            .appFont(.headline)
                    } else {
                        Text(String(localized: "home.welcome"))
                            .appFont(.headline)
                    }
                }
                Spacer()
            }
            .padding(DS.Spacing.lg)
        }
        .dsCard(radius: DS.Radius.lg)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Getting Started Card

private struct GettingStartedCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Label(String(localized: "home.getstarted.title"), systemImage: "sparkles")
                .appFont(.headline)
            Text(String(localized: "home.getstarted.body"))
                .appFont(.body)
                .foregroundStyle(DS.Colors.textSecondary)
        }
        .padding(DS.Spacing.lg)
        .dsCard(radius: DS.Radius.lg)
    }
}

// MARK: - Profile Summary (reusable)

private struct ProfileSummary: View {
    let profile: Profile
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            if let url = profile.avatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure(_): Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundColor(DS.Colors.textSecondary)
                    case .empty: ProgressView()
                    @unknown default: EmptyView()
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundColor(DS.Colors.textSecondary)
                    .frame(width: 56, height: 56)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name.isEmpty ? "" : profile.name).appFont(.headline)
                if !profile.contact.isEmpty { Text(profile.contact).foregroundColor(DS.Colors.textSecondary) }
                Text(profile.subscriptionStatus.rawValue)
                    .appFont(.footnoteSemibold)
                    .foregroundColor(DS.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, DS.Spacing.sm)
        .accessibilityElement(children: .combine)
    }
}
