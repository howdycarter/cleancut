//
//  RootView.swift
//

import SwiftUI

struct RootView: View {
    @Environment(\.container) private var container
    @EnvironmentObject private var router: AppRouter
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    var body: some View {
        TabView {
            NavigationStack(path: $router.path) {
                HomeView()
                    .navigationTitle(Text("home.title"))
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .detail(let id):
                            DetailView(itemID: id)
                        case .home:
                            HomeView()
                        case .settings:
                            SettingsView()
                        }
                    }
            }
            .tabItem { Label("home.tab", systemImage: "house.fill") }

            SettingsView()
                .tabItem { Label("settings.tab", systemImage: "gearshape.fill") }
        }
        .tint(container.config.branding.accentColorHex.isEmpty ? DesignTokens.accentColor : (Color(hex: container.config.branding.accentColorHex) ?? DesignTokens.accentColor))
        .fullScreenCover(isPresented: shouldShowOnboardingBinding) {
            OnboardingCoordinator(
                style: container.config.onboardingStyle,
                pages: .defaultPages,
                done: { hasSeenOnboarding = true }
            )
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View { RootView() }
}

private extension RootView {
    var shouldShowOnboarding: Bool {
        container.config.featureFlags.onboarding && !hasSeenOnboarding
    }
    var shouldShowOnboardingBinding: Binding<Bool> {
        Binding(get: { shouldShowOnboarding }, set: { newValue in hasSeenOnboarding = !newValue })
    }
}
