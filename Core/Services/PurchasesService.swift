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
    public func configure() {}
    public func logIn(_ appUserId: String) async {}
    public func logOut() async {}
    public func refreshSubscriptionStatus() async {}
    public func loadOfferings(includeAll: Bool) async -> [PurchaseOption] { [] }
    public func purchase(packageIdentifier: String) async throws {
        throw PurchaseFriendlyError.unavailable
    }
    public func restorePurchases() async throws {
        throw PurchaseFriendlyError.unavailable
    }
    public func showManageSubscriptions() async {}
}

/// Missing status means refresh failed, not that a purchase was revoked.
enum PremiumAccess {
    static func resolve(current: Bool, notification: Notification, paywallEnabled: Bool) -> Bool {
        guard paywallEnabled else { return true }
        return notification.userInfo?["hasActiveEntitlement"] as? Bool ?? current
    }
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

import StoreKit
import UIKit

/// Native StoreKit 2 remains usable without a RevenueCat account or client key.
/// All prices and transactions come from StoreKit; none are simulated by this service.
@MainActor
final class StoreKitPurchasesService: PurchasesService {
    private let productIdentifiers: [String]
    private var updatesTask: Task<Void, Never>?
    private(set) var hasActiveEntitlement = false

    nonisolated init(productIdentifiers: [String]) { self.productIdentifiers = productIdentifiers }

    nonisolated func configure() {
        Task { @MainActor [weak self] in self?.startMonitoring() }
    }

    private func startMonitoring() {
        guard updatesTask == nil else { return }
        updatesTask = Task { @MainActor [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard let self else { return }
                guard case .verified(let transaction) = result,
                      self.productIdentifiers.contains(transaction.productID) else { continue }
                await self.refreshSubscriptionStatus()
                await transaction.finish()
            }
        }
    }

    func stopMonitoring() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    func logIn(_ appUserId: String) async { await refreshSubscriptionStatus() }
    func logOut() async { await refreshSubscriptionStatus() }

    func loadOfferings(includeAll: Bool) async -> [PurchaseOption] {
        guard let products = try? await Product.products(for: productIdentifiers) else { return [] }
        return products.sorted { $0.price < $1.price }.map { product in
            let period = product.subscription?.subscriptionPeriod
            let annual = period?.unit == .year
            let cadence: String?
            if let period {
                let unit: String
                switch period.unit {
                case .day: unit = period.value == 1 ? "day" : "days"
                case .week: unit = period.value == 1 ? "week" : "weeks"
                case .month: unit = period.value == 1 ? "month" : "months"
                case .year: unit = period.value == 1 ? "year" : "years"
                @unknown default: unit = "period"
                }
                cadence = "Every \(period.value) \(unit)"
            } else { cadence = "One-time purchase" }
            return PurchaseOption(id: product.id, displayName: product.displayName, price: product.displayPrice,
                                  pricePerPeriod: cadence, badge: nil, isRecommended: annual, ctaText: "Subscribe")
        }
    }

    func purchase(packageIdentifier: String) async throws {
        guard productIdentifiers.contains(packageIdentifier),
              let product = try await Product.products(for: [packageIdentifier]).first else {
            throw PurchaseFriendlyError.unavailable
        }
        switch try await product.purchase() {
        case .success(let result):
            guard case .verified(let transaction) = result else {
                throw PurchaseFriendlyError.unknown("Your purchase could not be verified. Please restore purchases or try again.")
            }
            await refreshSubscriptionStatus()
            await transaction.finish()
        case .userCancelled: throw PurchaseFriendlyError.cancelled
        case .pending: throw PurchaseFriendlyError.unknown("Your purchase is awaiting approval. Pro will unlock when the App Store confirms it.")
        @unknown default: throw PurchaseFriendlyError.unavailable
        }
    }

    func refreshSubscriptionStatus() async {
        var active: Transaction?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  productIdentifiers.contains(transaction.productID),
                  transaction.revocationDate == nil, !transaction.isUpgraded else { continue }
            // currentEntitlements includes valid subscriptions during billing grace periods.
            active = transaction
        }
        hasActiveEntitlement = active != nil
        var info: [String: Any] = ["hasActiveEntitlement": hasActiveEntitlement]
        if let active {
            info["productId"] = active.productID
            if let expires = active.expirationDate { info[SubscriptionEventKey.expiresAt] = expires }
            if let product = try? await Product.products(for: [active.productID]).first {
                info[SubscriptionEventKey.productName] = product.displayName
                if let subscription = product.subscription, let statuses = try? await subscription.status {
                    for status in statuses {
                        guard case .verified(let transaction) = status.transaction,
                              transaction.productID == active.productID,
                              case .verified(let renewal) = status.renewalInfo else { continue }
                        info["willRenew"] = renewal.willAutoRenew
                    }
                }
            }
        }
        NotificationCenter.default.post(name: .subscriptionDidChange, object: nil, userInfo: info)
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshSubscriptionStatus()
        guard hasActiveEntitlement else {
            throw PurchaseFriendlyError.unknown("No active Pro purchase was found for this Apple Account.")
        }
    }

    func showManageSubscriptions() async {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        try? await AppStore.showManageSubscriptions(in: scene)
    }
}
