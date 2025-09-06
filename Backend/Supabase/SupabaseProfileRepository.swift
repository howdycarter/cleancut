//
//  SupabaseProfileRepository.swift
//

import Foundation

#if canImport(Supabase)
import Supabase

actor SupabaseProfileRepository: ProfileRepository {
    private let client: SupabaseClient
    private let table = "profiles"
    private let bucket = "avatars"

    init(url: URL = Secrets.supabaseURL, key: String = Secrets.supabaseAnonKey) {
        self.client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }

    func fetchProfile(for userId: String) async throws -> Profile? {
        struct Row: Codable {
            var id: String
            var name: String?
            var gender: String?
            var contact: String?
            var avatar_url: String?
            var subscription_status: String?
            var updated_at: Date?
        }
        let rows: [Row] = try await client.database
            .from(table)
            .select()
            .eq("id", value: userId)
            .execute()
            .value
        guard let r = rows.first else { return nil }
        return Profile(
            id: r.id,
            name: r.name ?? "",
            gender: Gender(rawValue: (r.gender ?? "unspecified")) ?? .unspecified,
            contact: r.contact ?? "",
            avatarURL: r.avatar_url.flatMap(URL.init(string:)),
            subscriptionStatus: Profile.SubscriptionStatus(rawValue: r.subscription_status ?? "Free") ?? .free,
            updatedAt: r.updated_at
        )
    }

    func upsertProfile(_ profile: Profile) async throws {
        struct Row: Codable {
            var id: String
            var name: String
            var gender: String
            var contact: String
            var avatar_url: String?
            var subscription_status: String?
            var updated_at: Date?
        }
        let row = Row(
            id: profile.id,
            name: profile.name,
            gender: profile.gender.rawValue,
            contact: profile.contact,
            avatar_url: profile.avatarURL?.absoluteString,
            subscription_status: profile.subscriptionStatus.rawValue,
            updated_at: Date()
        )
        _ = try await client.database
            .from(table)
            .upsert(row, onConflict: "id", returning: .minimal)
            .execute()
    }

    func uploadAvatar(data: Data, for userId: String, contentType: String) async throws -> URL {
        let path = "\(userId)/avatar-\(UUID().uuidString).jpg"
        _ = try await client.storage
            .from(bucket)
            .upload(path: path, file: data, options: .init(contentType: contentType, upsert: true))
        // return a public URL assuming the bucket has public policy
        return try client.storage.from(bucket).getPublicURL(path: path)
    }
}

#else

// When Supabase SDK is not available, provide a compile-time placeholder.
struct SupabaseProfileRepositoryUnavailable: ProfileRepository {
    func fetchProfile(for userId: String) async throws -> Profile? { nil }
    func upsertProfile(_ profile: Profile) async throws {}
    func uploadAvatar(data: Data, for userId: String, contentType: String) async throws -> URL {
        return URL(string: "https://example.local/unavailable.jpg")!
    }
}

#endif
