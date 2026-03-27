//
//  RootView.swift
//

import SwiftUI

struct RootView: View {
    @Environment(\.container) private var container
    @EnvironmentObject private var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @AppStorage("forceOnboardingOnce") private var forceOnboardingOnce: Bool = false
    @State private var isAuthenticated: Bool = false
    @State private var checkedAuthOnce: Bool = false
    @State private var isShowingPaywall: Bool = false
    @State private var hasActiveEntitlement: Bool? = nil

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
                        case .notifications:
                            NotificationsDebugView()
                        case .paywall:
                            Color.clear
                                .onAppear {
                                    // Present paywall as a bottom sheet instead of navigating
                                    isShowingPaywall = true
                                    // Remove the placeholder route to keep stack clean
                                    router.path.removeLast()
                                }
                        case .aiChat:
                            AIChatView()
                        case .aiImages:
                            AIImageGenView()
                        case .aiVision:
                            AIVisionView()
                        }
                    }
            }
            .tabItem { Label("home.tab", systemImage: "house.fill") }

            SettingsView()
                .tabItem { Label("settings.tab", systemImage: "gearshape.fill") }
        }
        .tint(DS.accent)
        .sheet(isPresented: $isShowingPaywall) {
            Group {
                if #available(iOS 16.4, *) {
                    PaywallView()
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    PaywallView()
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isShowingPaywall)
        .fullScreenCover(isPresented: shouldShowOnboardingBinding) {
            OnboardingCoordinator(
                style: container.config.onboardingStyle,
                pages: .defaultPages,
                done: {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        hasSeenOnboarding = true
                        forceOnboardingOnce = false
                    }
                }
            )
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
        .animation(.easeInOut(duration: 0.3), value: shouldShowOnboarding)
        .fullScreenCover(isPresented: shouldShowAuthBinding) {
            AuthCoordinator { user in
                withAnimation(.easeInOut(duration: 0.35)) {
                    isAuthenticated = true
                }
                Task {
                    await container.purchasesService.logIn(user.id)
                    await container.purchasesService.refreshSubscriptionStatus()
                }
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
        .animation(.easeInOut(duration: 0.3), value: shouldShowAuth)
        .task {
            if container.config.featureFlags.auth {
                let user = await container.authRepository.currentUser()
                self.isAuthenticated = (user != nil)
                self.checkedAuthOnce = true
                // Link RevenueCat to the user on cold start and refresh entitlements
                if let u = user {
                    await container.purchasesService.logIn(u.id)
                    await container.purchasesService.refreshSubscriptionStatus()
                }
                if user != nil {
                    AppLogger.log("Auth status: Logged In", level: .info)
                } else {
                    AppLogger.log("Auth status: Logged Out", level: .info)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .authStatusDidChange)) { _ in
            Task { @MainActor in
                let user = await container.authRepository.currentUser()
                self.isAuthenticated = (user != nil)
                self.checkedAuthOnce = true
                if let u = user {
                    await container.purchasesService.logIn(u.id)
                    await container.purchasesService.refreshSubscriptionStatus()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionDidChange)) { note in
            guard container.config.featureFlags.paywall else { return }
            let active = note.userInfo?["hasActiveEntitlement"] as? Bool
            hasActiveEntitlement = active
            if checkedAuthOnce && isAuthenticated {
                if active == false { isShowingPaywall = true }
                if active == true { isShowingPaywall = false }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                Task {
                    if let u = await container.authRepository.currentUser() {
                        await container.purchasesService.logIn(u.id)
                        await container.purchasesService.refreshSubscriptionStatus()
                    }
                }
            }
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View { RootView() }
}

private extension RootView {
    var shouldShowOnboarding: Bool {
        (container.config.featureFlags.onboarding && !hasSeenOnboarding) || forceOnboardingOnce
    }
    var shouldShowOnboardingBinding: Binding<Bool> {
        Binding(get: { shouldShowOnboarding }, set: { newValue in
            if newValue == false { forceOnboardingOnce = false }
            hasSeenOnboarding = !newValue
        })
    }
    var shouldShowAuth: Bool {
        container.config.featureFlags.auth && checkedAuthOnce && !isAuthenticated
    }
    var shouldShowAuthBinding: Binding<Bool> {
        Binding(get: { shouldShowAuth }, set: { newValue in isAuthenticated = !newValue })
    }
    // StoreKit paywall removed.
}
