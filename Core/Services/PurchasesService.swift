//
//  PurchasesService.swift
//

import Foundation

public protocol PurchasesService: Sendable {
    func configure()
    func logIn(_ appUserId: String) async
    func restorePurchases() async throws
    func logOut() async
    func refreshSubscriptionStatus() async

    // Paywall/Offerings
    func loadOfferings(includeAll: Bool) async -> [PurchaseOption]
    func purchase(packageIdentifier: String) async throws
    func showManageSubscriptions() async
}

public struct NoopPurchasesService: PurchasesService {
    public init() {}
    public func configure() {
        #if DEBUG
        print("[Purchases] NoopPurchasesService active — showing demo offerings. Configure RevenueCat in Secrets.swift to enable real subscriptions.")
        #endif
    }
    public func logIn(_ appUserId: String) async {}
    public func restorePurchases() async throws {}
    public func logOut() async {}
    public func refreshSubscriptionStatus() async {}
    public func loadOfferings(includeAll: Bool) async -> [PurchaseOption] {
        // Lightweight local placeholders for previews/testing without RevenueCat
        var base: [PurchaseOption] = [
            PurchaseOption(
                id: "com.swiftkit.pro.6m",
                displayName: "6 Months",
                price: "$39.99",
                pricePerPeriod: "$6.67/mo",
                badge: "19% OFF",
                isRecommended: true,
                ctaText: "Start 1 week free trial"
            ),
            PurchaseOption(
                id: "com.swiftkit.pro.monthly",
                displayName: "Month",
                price: "$9.99",
                pricePerPeriod: nil,
                badge: nil,
                isRecommended: false,
                ctaText: "Continue"
            )
        ]
        if includeAll {
            base.append(
                PurchaseOption(
                    id: "com.swiftkit.premium.yearly",
                    displayName: "Year",
                    price: "$79.99",
                    pricePerPeriod: "$6.67/mo",
                    badge: "Best Value",
                    isRecommended: true,
                    ctaText: nil
                )
            )
        }
        return base
    }
    public func purchase(packageIdentifier: String) async throws {}
    public func showManageSubscriptions() async { /* no-op without SDK */ }
}

// MARK: - Models

public struct PurchaseOption: Identifiable, Sendable, Equatable {
    public let id: String                 // stable RevenueCat packageIdentifier or product id
    public let displayName: String        // e.g. "1 Month", "1 Year", "6 Months"
    public let price: String              // localized price, e.g., $9.99
    public let pricePerPeriod: String?    // e.g., $6.67/mo
    public let badge: String?             // e.g., "19% OFF" or "Best Value"
    public let isRecommended: Bool
    public let ctaText: String?
}
