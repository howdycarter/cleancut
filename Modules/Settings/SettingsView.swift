//
//  SettingsView.swift
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.container) private var container
    @EnvironmentObject private var router: AppRouter
    @Environment(\.colorScheme) private var scheme
    @AppStorage("appearanceDark") private var appearanceDark: Bool = false
    @AppStorage("appearanceLocked") private var appearanceLocked: Bool = false
    @State private var currentUser: User?
    @State private var profile: Profile?
    @State private var subscription: SubscriptionStatus?
    @State private var purchasedNameOverride: String? = nil
    @State private var purchasedExpiresOverride: Date? = nil
    @State private var hasActiveEntitlement: Bool = false
    @State private var willRenew: Bool? = nil
    @State private var showDeleteAlert: Bool = false
    @State private var purchaseErrorMessage: String? = nil
    // Theme style picker removed from settings UI per request

    var body: some View {
        NavigationStack {
            List {
                if let profile {
                    Section {
                        HStack(spacing: DesignTokens.Spacing.md) {
                            if let url = profile.avatarURL {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image): image.resizable().scaledToFill()
                                    case .failure(_): Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundColor(.secondary)
                                    case .empty: ProgressView()
                                    @unknown default: EmptyView()
                                    }
                                }
                                .frame(width: 56, height: 56)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundColor(.secondary)
                                    .frame(width: 56, height: 56)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.name.isEmpty ? "" : profile.name).font(.headline)
                                if let currentUser { Text(currentUser.email).foregroundColor(.secondary) }
                            }
                        }
                        .padding(.vertical, DesignTokens.Spacing.sm)
                    }
                }
                if let currentSub = subscription {
                    Section("Subscription") {
                        HStack {
                            Label(subscriptionDisplayText, systemImage: "crown.fill")
                                .foregroundColor(.secondary)
                            Spacer()
                            if let exp = effectiveExpiryDate {
                                Text(exp, style: .date).foregroundColor(.secondary)
                            }
                        }
                        if currentSub.plan == .free && !hasActiveEntitlement {
                            Button {
                                router.push(.paywall)
                            } label: {
                                Label("Upgrade", systemImage: "sparkles")
                            }
                        }
                        if hasActiveEntitlement, willRenew == false {
                            Text("Subscription cancelled")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.red)
                            if let exp = effectiveExpiryDate {
                                Text("\(currentSub.plan.rawValue.capitalized) plan ends on: \(exp, style: .date)")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Button {
                            Task {
                                do {
                                    try await container.purchasesService.restorePurchases()
                                    await container.purchasesService.refreshSubscriptionStatus()
                                } catch let e as PurchaseFriendlyError {
                                    purchaseErrorMessage = e.localizedDescription
                                } catch {
                                    purchaseErrorMessage = error.localizedDescription
                                }
                            }
                        } label: {
                            Label("Restore Purchases", systemImage: "arrow.clockwise")
                        }
                        Button {
                            Task {
                                await container.purchasesService.showManageSubscriptions()
                                await container.purchasesService.refreshSubscriptionStatus()
                            }
                        } label: {
                            Label("Manage Subscription", systemImage: "link")
                        }
                        Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                            Label("Manage in App Store", systemImage: "safari")
                        }
                    }
                }
                Section("settings.appearance") {
                    Toggle(isOn: Binding(
                        get: { appearanceLocked ? appearanceDark : (scheme == .dark) },
                        set: { newValue in
                            appearanceDark = newValue
                            appearanceLocked = true
                        }
                    )) {
                        Label("settings.darkmode", systemImage: "moon.fill")
                    }
                }

                Section("settings.legal") {
                    Link(destination: container.config.legal.privacyPolicyURL) {
                        Label("settings.privacy", systemImage: "hand.raised")
                    }
                    Link(destination: container.config.legal.termsURL) {
                        Label("settings.terms", systemImage: "doc.text")
                    }
                }

                if container.config.featureFlags.auth {
                    Section("account.section") {
                        if let currentUser {
                            Label(currentUser.email, systemImage: "person.crop.circle")
                                .foregroundColor(.secondary)
                        }
                        Button(role: .none) {
                            Task {
                                await container.authRepository.signOut()
                                await container.purchasesService.logOut()
                                // Immediately reset local subscription state on logout
                                await MainActor.run {
                                    currentUser = nil
                                    subscription = .init(plan: .free, expiresAt: nil)
                                    hasActiveEntitlement = false
                                    purchasedNameOverride = nil
                                    purchasedExpiresOverride = nil
                                }
                                NotificationCenter.default.post(name: .authStatusDidChange, object: nil)
                            }
                        } label: {
                            Label("auth.signout", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        Button(role: .destructive) { showDeleteAlert = true } label: {
                            Label("account.delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(Text("settings.title"))
            // Global preferredColorScheme is applied at app root
            .task {
                if container.config.featureFlags.auth {
                    currentUser = await container.authRepository.currentUser()
                    if let user = currentUser {
                        do { profile = try await container.profileRepository.fetchProfile(for: user.id) } catch { profile = nil }
                        // Start from Free, then RevenueCat refresh will update if needed
                        subscription = .init(plan: .free, expiresAt: nil)
                        await container.purchasesService.refreshSubscriptionStatus()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .subscriptionDidChange)) { note in
                if let name = note.userInfo?[SubscriptionEventKey.productName] as? String, !name.isEmpty {
                    purchasedNameOverride = name
                }
                if let exp = note.userInfo?[SubscriptionEventKey.expiresAt] as? Date {
                    purchasedExpiresOverride = exp
                }
                if let active = note.userInfo?["hasActiveEntitlement"] as? Bool {
                    hasActiveEntitlement = active
                    if active == false {
                        purchasedNameOverride = nil
                        purchasedExpiresOverride = nil
                        subscription = .init(plan: .free, expiresAt: nil)
                    } else {
                        // Update local subscription snapshot for instant UI
                        let productId = (note.userInfo?["productId"] as? String)?.lowercased()
                        let mappedPlan: SubscriptionPlan = {
                            if let pid = productId, pid.contains("premium") { return .premium }
                            return .pro
                        }()
                        let exp = note.userInfo?[SubscriptionEventKey.expiresAt] as? Date
                        subscription = .init(plan: mappedPlan, expiresAt: exp)
                    }
                }
                if let renew = note.userInfo?["willRenew"] as? Bool { willRenew = renew }
            }
            .onReceive(NotificationCenter.default.publisher(for: .authStatusDidChange)) { _ in
                Task {
                    let user = await container.authRepository.currentUser()
                    if let u = user {
                        // On login: link RC to supabase user, then refresh (no restore to avoid App Store prompt)
                        await container.purchasesService.logIn(u.id)
                        await container.purchasesService.refreshSubscriptionStatus()
                    } else {
                        // On logout ensure Free
                        await MainActor.run {
                            subscription = .init(plan: .free, expiresAt: nil)
                            hasActiveEntitlement = false
                            purchasedNameOverride = nil
                            purchasedExpiresOverride = nil
                        }
                    }
                }
            }
            .alert("account.delete.confirm", isPresented: $showDeleteAlert) {
                Button("generic.cancel", role: .cancel) {}
                Button("account.delete.action", role: .destructive) {
                    Task {
                        if let u = await container.authRepository.currentUser() {
                            await AccountDeletionService.requestDeletionIfConfigured(userId: u.id, email: u.email)
                        }
                        await container.authRepository.signOut()
                        currentUser = nil
                        NotificationCenter.default.post(name: .authStatusDidChange, object: nil)
                    }
                }
            } message: {
                Text("account.delete.message")
            }
        }
        // No local color scheme override here; persistence handled via AppStorage
        .alert("Subscription", isPresented: .constant(purchaseErrorMessage != nil)) {
            Button("OK") { purchaseErrorMessage = nil }
        } message: {
            Text(purchaseErrorMessage ?? "")
        }
        .animation(.easeInOut(duration: 0.25), value: subscription)
        .animation(.easeInOut(duration: 0.25), value: hasActiveEntitlement)
        .animation(.easeInOut(duration: 0.25), value: willRenew)
    }
}

private extension SettingsView {
    var subscriptionDisplayText: String {
        if let override = purchasedNameOverride, !override.isEmpty {
            return override
        }
        if let s = subscription { return s.plan.rawValue.capitalized }
        return "Free"
    }
    var effectiveExpiryDate: Date? { purchasedExpiresOverride ?? subscription?.expiresAt }
}
