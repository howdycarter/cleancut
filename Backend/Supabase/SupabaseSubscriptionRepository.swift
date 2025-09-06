//
//  SupabaseSubscriptionRepository.swift
//

import Foundation

#if canImport(Supabase)
import Supabase

actor SupabaseSubscriptionRepository: SubscriptionRepository {
    private let client: SupabaseClient
    private let table = "user_subscriptions"

    init(url: URL = Secrets.supabaseURL, key: String = Secrets.supabaseAnonKey) {
        self.client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }

    func fetch(for userId: String) async throws -> SubscriptionStatus? {
        struct Row: Codable { let user_id: String; let plan: String; let expires_at: Date? }
        let rows: [Row] = try await client.database
            .from(table)
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        guard let r = rows.first, let plan = SubscriptionPlan(rawValue: r.plan) else { return .init(plan: .free, expiresAt: nil) }
        return .init(plan: plan, expiresAt: r.expires_at)
    }
}

#else

struct SupabaseSubscriptionRepositoryUnavailable: SubscriptionRepository {
    func fetch(for userId: String) async throws -> SubscriptionStatus? { .init(plan: .free, expiresAt: nil) }
}

#endif
