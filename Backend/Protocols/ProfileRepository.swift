//
//  ProfileRepository.swift
//

import Foundation

public enum Gender: String, Codable, CaseIterable, Sendable {
    case unspecified
    case male
    case female
    case other
}

public struct Profile: Codable, Equatable, Sendable, Identifiable {
    public var id: String // same as auth user id
    public var name: String
    public var gender: Gender
    public var contact: String
    public var avatarURL: URL?
    public enum SubscriptionStatus: String, Codable, Sendable, CaseIterable { case free = "Free", premiumMonthly = "Premium Monthly", premiumYearly = "Premium Yearly" }
    public var subscriptionStatus: SubscriptionStatus
    public var updatedAt: Date?
    public init(id: String,
                name: String = "",
                gender: Gender = .unspecified,
                contact: String = "",
                avatarURL: URL? = nil,
                subscriptionStatus: SubscriptionStatus = .free,
                updatedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.gender = gender
        self.contact = contact
        self.avatarURL = avatarURL
        self.subscriptionStatus = subscriptionStatus
        self.updatedAt = updatedAt
    }
}

public protocol ProfileRepository: Sendable {
    func fetchProfile(for userId: String) async throws -> Profile?
    func upsertProfile(_ profile: Profile) async throws
    func uploadAvatar(data: Data, for userId: String, contentType: String) async throws -> URL
}

public final class LocalProfileRepository: ProfileRepository {
    private var storage: [String: Profile] = [:]
    public init() {}
    public func fetchProfile(for userId: String) async throws -> Profile? {
        storage[userId]
    }
    public func upsertProfile(_ profile: Profile) async throws {
        storage[profile.id] = profile
    }
    public func uploadAvatar(data: Data, for userId: String, contentType: String) async throws -> URL {
        // Local mode: pretend upload and return a fake URL
        return URL(string: "https://example.local/avatars/\(userId)/placeholder.jpg")!
    }
}
