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
    public var appleSignInService: AppleSignInServiceProtocol
    /// The shared cache manager. Access this to manually get/set/invalidate cache entries.
    public var cacheManager: CacheManager

    public init(config: AppConfig,
                authRepository: AuthRepository,
                userRepository: UserRepository,
                profileRepository: ProfileRepository,
                subscriptionRepository: SubscriptionRepository,
                purchasesService: PurchasesService,
                analytics: AnalyticsService,
                appleSignInService: AppleSignInServiceProtocol,
                cacheManager: CacheManager = .shared) {
        self.config = config
        self.authRepository = authRepository
        self.userRepository = userRepository
        self.profileRepository = profileRepository
        self.subscriptionRepository = subscriptionRepository
        self.purchasesService = purchasesService
        self.analytics = analytics
        self.appleSignInService = appleSignInService
        self.cacheManager = cacheManager
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

        // Base profile repository (uncached)
        let baseProfile: ProfileRepository
        switch config.backend {
        case .local:
            baseProfile = LocalProfileRepository()
        case .supabase:
            #if canImport(Supabase)
            baseProfile = SupabaseProfileRepository()
            #else
            baseProfile = LocalProfileRepository()
            #endif
        }

        // Base subscription repository (uncached)
        let baseSubscriptionRepo: SubscriptionRepository
        switch config.backend {
        case .local:
            baseSubscriptionRepo = LocalSubscriptionRepository()
        case .supabase:
            #if canImport(Supabase)
            baseSubscriptionRepo = SupabaseSubscriptionRepository()
            #else
            baseSubscriptionRepo = LocalSubscriptionRepository()
            #endif
        }

        // Wrap repositories in caching decorators when the feature flag is enabled.
        // When caching is off the base implementations are used directly -- zero overhead.
        let cacheManager = CacheManager.shared
        let profile: ProfileRepository
        let subscriptionRepo: SubscriptionRepository
        if config.featureFlags.enableCaching {
            profile = CachedProfileRepository(remote: baseProfile, cache: cacheManager)
            subscriptionRepo = CachedSubscriptionRepository(remote: baseSubscriptionRepo, cache: cacheManager)
        } else {
            profile = baseProfile
            subscriptionRepo = baseSubscriptionRepo
        }
        let purchases: PurchasesService
        #if canImport(RevenueCat)
        if !Secrets.revenueCatAPIKey.isEmpty {
            purchases = RevenueCatPurchasesService(apiKey: Secrets.revenueCatAPIKey)
        } else {
            purchases = NoopPurchasesService()
            AppLogger.log("[Noop] RevenueCat API key is empty — using demo offerings. Set revenueCatAPIKey in Secrets.swift to enable real subscriptions.", level: .warning)
        }
        #else
        purchases = NoopPurchasesService()
        AppLogger.log("[Noop] RevenueCat SDK not linked — using demo offerings. Add the RevenueCat package to enable real subscriptions.", level: .warning)
        #endif

        // Analytics service (TelemetryDeck/TelemetryClient when available)
        let analytics: AnalyticsService
        #if canImport(TelemetryDeck) || canImport(TelemetryClient)
        if Secrets.telemetryDeckAppID.isEmpty {
            analytics = NoopAnalyticsService()
            AppLogger.log("[Noop] TelemetryDeck app ID is empty — analytics events are not being sent. Set telemetryDeckAppID in Secrets.swift.", level: .warning)
        } else {
            analytics = TelemetryDeckAnalyticsService(appID: Secrets.telemetryDeckAppID)
        }
        #else
        analytics = NoopAnalyticsService()
        AppLogger.log("[Noop] TelemetryDeck SDK not linked — analytics disabled.", level: .warning)
        #endif

        // Apple Sign-In service — use live service for Supabase, mock for local.
        let appleSignIn: AppleSignInServiceProtocol
        switch config.backend {
        case .supabase:
            appleSignIn = AppleSignInService()
        case .local:
            appleSignIn = MockAppleSignInService()
        }

        return DIContainer(config: config,
                           authRepository: auth,
                           userRepository: user,
                           profileRepository: profile,
                           subscriptionRepository: subscriptionRepo,
                           purchasesService: purchases,
                           analytics: analytics,
                           appleSignInService: appleSignIn,
                           cacheManager: cacheManager)
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
