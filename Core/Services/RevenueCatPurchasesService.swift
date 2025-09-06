//
//  RevenueCatPurchasesService.swift
//

import Foundation

#if canImport(RevenueCat)
import RevenueCat

struct RevenueCatPurchasesService: PurchasesService {
    private let apiKey: String

    init(apiKey: String) { self.apiKey = apiKey }

    func configure() {
        guard !apiKey.isEmpty else { return }
        let config = Configuration
            .builder(withAPIKey: apiKey)
            .with(usesStoreKit2IfAvailable: true)
            .build()
        Purchases.configure(with: config)
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif
    }

    func logIn(_ appUserId: String) async {
        guard !appUserId.isEmpty, !apiKey.isEmpty else { return }
        _ = try? await Purchases.shared.logIn(appUserId)
        // Attach Supabase user id for debugging / support visibility in RevenueCat
        Purchases.shared.attribution.setAttributes(["supabase_user_id": appUserId])
    }

    func restorePurchases() async throws {
        do {
            _ = try await Purchases.shared.restorePurchases()
            await broadcastSubscriptionChange(source: "restore")
        }
        catch { throw map(error) }
    }

    func logOut() async {
        try? await Purchases.shared.logOut()
        // Clear cached CustomerInfo so next fetch reflects anonymous state
        Purchases.shared.invalidateCustomerInfoCache()
    }

    func loadOfferings(includeAll: Bool) async -> [PurchaseOption] {
        do {
            let offerings = try await Purchases.shared.offerings()
            // Helper to map a package -> PurchaseOption
            func mapPkg(_ pkg: Package) -> PurchaseOption? {
                let product = pkg.storeProduct
                let id = pkg.identifier // Stable RC package identifier
                let price = product.localizedPriceString

                var displayName: String = product.localizedTitle
                if let period = product.subscriptionPeriod {
                    switch period.unit {
                    case .day: displayName = period.value == 7 ? "Week" : "\(period.value) Days"
                    case .week: displayName = period.value == 1 ? "Week" : "\(period.value) Weeks"
                    case .month: displayName = period.value == 1 ? "Month" : "\(period.value) Months"
                    case .year: displayName = period.value == 1 ? "Year" : "\(period.value) Years"
                    @unknown default: break
                    }
                }

                var per: String? = nil
                if let period = product.subscriptionPeriod {
                    // Compute per-month for multi-month/year products
                    let months: Int = {
                        switch period.unit {
                        case .month: return period.value
                        case .year: return period.value * 12
                        case .week: return Int(Double(period.value) / 4.0)
                        case .day: return Int(Double(period.value) / 30.0)
                        @unknown default: return 0
                        }
                    }()
                    if months > 1 {
                        let total = NSDecimalNumber(decimal: product.price)
                        let unit = total.dividing(by: NSDecimalNumber(value: months))
                        let formatter = NumberFormatter()
                        formatter.numberStyle = .currency
                        if let code = product.currencyCode { formatter.currencyCode = code }
                        per = (formatter.string(from: unit) ?? "") + "/mo"
                    }
                }

                let isAnnual = product.subscriptionPeriod?.unit == .year
                let isSixMonth = (product.subscriptionPeriod?.unit == .month && product.subscriptionPeriod?.value == 6)
                let badge = isAnnual ? "Best Value" : (isSixMonth ? "19% OFF" : nil)

                var cta: String? = nil
                if let intro = product.introductoryDiscount {
                    // Prefer explicit free trial phrases when possible
                    let isFreeTrial = intro.price == 0 || intro.paymentMode == .freeTrial
                    if isFreeTrial {
                        let unitText: String
                        let value: Int
                        #if swift(>=5.8)
                        value = intro.subscriptionPeriod.value
                        switch intro.subscriptionPeriod.unit {
                        case .day: unitText = value == 1 ? "day" : "days"
                        case .week: unitText = value == 1 ? "week" : "weeks"
                        case .month: unitText = value == 1 ? "month" : "months"
                        case .year: unitText = value == 1 ? "year" : "years"
                        @unknown default: unitText = "days"
                        }
                        #else
                        value = 0; unitText = "days"
                        #endif
                        cta = value > 0 ? "Start \(value) \(unitText) free trial" : "Start free trial"
                    }
                }

                return PurchaseOption(id: id,
                                      displayName: displayName,
                                      price: price,
                                      pricePerPeriod: per,
                                      badge: badge,
                                      isRecommended: isAnnual || isSixMonth,
                                      ctaText: cta)
            }

            if includeAll {
                var seen = Set<String>()
                var all: [PurchaseOption] = []
                // Prefer to list current offering packages first
                if let current = offerings.current {
                    for pkg in current.availablePackages {
                        if let opt = mapPkg(pkg), !seen.contains(opt.id) {
                            all.append(opt); seen.insert(opt.id)
                        }
                    }
                }
                for offering in offerings.all.values {
                    for pkg in offering.availablePackages {
                        if let opt = mapPkg(pkg), !seen.contains(opt.id) {
                            all.append(opt); seen.insert(opt.id)
                        }
                    }
                }
                return all
            } else {
                guard let current = offerings.current else { return [] }
                return current.availablePackages.compactMap(mapPkg)
            }
        } catch {
            AppLogger.log("Offerings fetch failed: \(error.localizedDescription)", level: .error)
            return []
        }
    }

    func purchase(packageIdentifier: String) async throws {
        let offerings = try await Purchases.shared.offerings()
        // Search across all offerings for the selected package identifier
        let pkg: Package? = {
            for offering in offerings.all.values {
                if let found = offering.availablePackages.first(where: { $0.identifier == packageIdentifier }) {
                    return found
                }
            }
            return nil
        }()
        guard let pkg else {
            throw NSError(domain: "Purchases", code: -1, userInfo: [NSLocalizedDescriptionKey: "Package not found"])
        }
        do {
            _ = try await Purchases.shared.purchase(package: pkg)
            await broadcastSubscriptionChange(source: "purchase")
        }
        catch { throw map(error) }
    }

    func showManageSubscriptions() async { try? await Purchases.shared.showManageSubscriptions() }

    private func map(_ error: Swift.Error) -> Error {
        // Map RevenueCat/NSError to domain-level friendly errors when possible
        let ns = error as NSError
        let message = ns.localizedDescription
        let domain = ns.domain.lowercased()
        if domain.contains("revenuecat") {
            let desc = message.lowercased()
            if desc.contains("ownership") || desc.contains("receipt") && desc.contains("in use") {
                return PurchaseFriendlyError.ownershipConflict
            }
            if desc.contains("cancelled") { return PurchaseFriendlyError.cancelled }
            if desc.contains("network") { return PurchaseFriendlyError.network }
        }
        if ns.domain == NSURLErrorDomain { return PurchaseFriendlyError.network }
        return PurchaseFriendlyError.unknown(message)
    }

    func refreshSubscriptionStatus() async {
        // Ensure next CustomerInfo fetch hits the network (avoid stale cache).
        // Avoid calling syncPurchases() here to prevent App Store sign-in prompts
        // during normal app launches and logins.
        Purchases.shared.invalidateCustomerInfoCache()
        await broadcastSubscriptionChange(source: "refresh")
    }

    // Notify app layers that subscription changed, with product name + optional expiry
    private func broadcastSubscriptionChange(source: String) async {
        do {
            let info = try await Purchases.shared.customerInfo()
            // Derive product id and expiration
            let productId: String? = info.activeSubscriptions.first
            var productName: String? = nil
            let activeEntitlement = info.entitlements.active.values.first
            var expiresAt: Date? = activeEntitlement?.expirationDate
            let hasActiveEntitlement: Bool = activeEntitlement?.isActive ?? false
            let willRenew: Bool = activeEntitlement?.willRenew ?? false
            let unsubscribeDetectedAt: Date? = activeEntitlement?.unsubscribeDetectedAt
            if let pid = productId, let offerings = try? await Purchases.shared.offerings() {
                outer: for offering in offerings.all.values {
                    for pkg in offering.availablePackages {
                        let sp = pkg.storeProduct
                        if sp.productIdentifier == pid {
                            // Reuse displayName mapping logic
                            var displayName: String = sp.localizedTitle
                            if let period = sp.subscriptionPeriod {
                                switch period.unit {
                                case .day: displayName = period.value == 7 ? "Week" : "\(period.value) Days"
                                case .week: displayName = period.value == 1 ? "Week" : "\(period.value) Weeks"
                                case .month: displayName = period.value == 1 ? "Monthly" : "\(period.value) Months"
                                case .year: displayName = period.value == 1 ? "Yearly" : "\(period.value) Years"
                                @unknown default: break
                                }
                            }
                            productName = displayName
                            break outer
                        }
                    }
                }
            }
            DispatchQueue.main.async {
                var payload: [String: Any] = [:]
                if let n = productName { payload[SubscriptionEventKey.productName] = n }
                if let e = expiresAt { payload[SubscriptionEventKey.expiresAt] = e }
                payload["source"] = source
                payload["hasActiveEntitlement"] = hasActiveEntitlement
                payload["willRenew"] = willRenew
                payload["appUserID"] = Purchases.shared.appUserID
                if let pid = productId { payload["productId"] = pid }
                if let unsub = unsubscribeDetectedAt { payload["unsubscribeDetectedAt"] = unsub }
                NotificationCenter.default.post(name: .subscriptionDidChange, object: nil, userInfo: payload)
            }
        } catch {
            // Post a bare event so listeners can refetch from RC if desired
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .subscriptionDidChange, object: nil, userInfo: ["source": source])
            }
        }
    }
}

#else

// Fallback stub when RevenueCat SDK isn't linked.
struct RevenueCatPurchasesServiceUnavailable: PurchasesService {
    func configure() {}
    func logIn(_ appUserId: String) async {}
    func restorePurchases() async throws {}
    func logOut() async {}
    func loadOfferings(includeAll: Bool) async -> [PurchaseOption] { [] }
    func refreshSubscriptionStatus() async {}
    func purchase(packageIdentifier: String) async throws {}
    func showManageSubscriptions() async {}
}

#endif
