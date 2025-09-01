//
//  FeatureFlags.swift
//

import Foundation

public struct FeatureFlags: Codable, Sendable {
    public var onboarding: Bool
    public var auth: Bool
    public var paywall: Bool
    public var notifications: Bool

    public init(
        onboarding: Bool = false,
        auth: Bool = false,
        paywall: Bool = false,
        notifications: Bool = false
    ) {
        self.onboarding = onboarding
        self.auth = auth
        self.paywall = paywall
        self.notifications = notifications
    }
}

public extension FeatureFlags {
    // Defaults are safe; the generator can overwrite values directly.
    static var `default`: FeatureFlags { FeatureFlags() }
}
