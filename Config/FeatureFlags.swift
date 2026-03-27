//
//  FeatureFlags.swift
//

import Foundation

public struct FeatureFlags: Codable, Sendable {
    public var onboarding: Bool
    public var auth: Bool
    public var paywall: Bool
    public var notifications: Bool
    /// Enable the AI feature module (chat, image gen, vision) on the home screen.
    public var aiFeatures: Bool
    /// Enable the "Sign in with Apple" button on the sign-in screen.
    /// Requires the "Sign in with Apple" capability in Xcode and a configured
    /// Apple provider in your Supabase project. See `AppleSignInService.swift` for setup steps.
    public var appleSignIn: Bool
    /// Enable the centralized caching layer.
    /// When `true`, repositories are wrapped in cached decorators (e.g.,
    /// `CachedProfileRepository`, `CachedSubscriptionRepository`) that serve
    /// fresh data from an in-memory + UserDefaults cache before hitting the network.
    /// Toggle this off to bypass caching entirely -- useful for debugging.
    public var enableCaching: Bool

    public init(
        onboarding: Bool = false,
        auth: Bool = false,
        paywall: Bool = false,
        notifications: Bool = false,
        aiFeatures: Bool = false,
        appleSignIn: Bool = false,
        enableCaching: Bool = true
    ) {
        self.onboarding = onboarding
        self.auth = auth
        self.paywall = paywall
        self.notifications = notifications
        self.aiFeatures = aiFeatures
        self.appleSignIn = appleSignIn
        self.enableCaching = enableCaching
    }
}

public extension FeatureFlags {
    // Defaults are safe; the generator can overwrite values directly.
    static var `default`: FeatureFlags { FeatureFlags() }
}
