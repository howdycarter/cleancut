//
//  DIContainer.swift
//

import Foundation

public struct DIContainer: Sendable {
    public var config: AppConfig
    public var authRepository: AuthRepository
    public var userRepository: UserRepository
    public var profileRepository: ProfileRepository
    public var subscriptionRepository: SubscriptionRepository
    public var purchasesService: PurchasesService
    public var analytics: AnalyticsService

    public init(config: AppConfig,
                authRepository: AuthRepository,
                userRepository: UserRepository,
                profileRepository: ProfileRepository,
                subscriptionRepository: SubscriptionRepository,
                purchasesService: PurchasesService,
                analytics: AnalyticsService) {
        self.config = config
        self.authRepository = authRepository
        self.userRepository = userRepository
        self.profileRepository = profileRepository
        self.subscriptionRepository = subscriptionRepository
        self.purchasesService = purchasesService
        self.analytics = analytics
    }
}

public extension DIContainer {
    static func makeDefault(config: AppConfig = .default) -> DIContainer {
        // Choose repository implementations based on backend selection.
        let auth: AuthRepository
        switch config.backend {
        case .local:
            auth = LocalAuthRepository()
        case .supabase:
            #if canImport(Supabase)
            auth = SupabaseAuthRepository()
            #else
            // Fallback to local when the Supabase SDK isn't linked yet.
            auth = LocalAuthRepository()
            #endif
        }
        let user = LocalUserRepository(auth: auth)
        let profile: ProfileRepository
        switch config.backend {
        case .local:
            profile = LocalProfileRepository()
        case .supabase:
            #if canImport(Supabase)
            profile = SupabaseProfileRepository()
            #else
            profile = LocalProfileRepository()
            #endif
        }
        // Subscription repository and purchases service
        let subscriptionRepo: SubscriptionRepository
        switch config.backend {
        case .local:
            subscriptionRepo = LocalSubscriptionRepository()
        case .supabase:
            #if canImport(Supabase)
            subscriptionRepo = SupabaseSubscriptionRepository()
            #else
            subscriptionRepo = LocalSubscriptionRepository()
            #endif
        }
        let purchases: PurchasesService
        #if canImport(RevenueCat)
        if !Secrets.revenueCatAPIKey.isEmpty {
            purchases = RevenueCatPurchasesService(apiKey: Secrets.revenueCatAPIKey)
        } else {
            purchases = NoopPurchasesService()
        }
        #else
        purchases = NoopPurchasesService()
        #endif

        // Analytics service (TelemetryDeck/TelemetryClient when available)
        let analytics: AnalyticsService
        #if canImport(TelemetryDeck) || canImport(TelemetryClient)
        analytics = TelemetryDeckAnalyticsService(appID: Secrets.telemetryDeckAppID)
        #else
        analytics = NoopAnalyticsService()
        #endif
        return DIContainer(config: config,
                           authRepository: auth,
                           userRepository: user,
                           profileRepository: profile,
                           subscriptionRepository: subscriptionRepo,
                           purchasesService: purchases,
                           analytics: analytics)
    }
}

private struct DIContainerKey: Sendable {}

import SwiftUI

private struct DIKey: EnvironmentKey {
    static let defaultValue: DIContainer = .makeDefault()
}

public extension EnvironmentValues {
    var container: DIContainer {
        get { self[DIKey.self] }
        set { self[DIKey.self] = newValue }
    }
}

public extension View {
    func inject(_ container: DIContainer) -> some View { environment(\.container, container) }
}
