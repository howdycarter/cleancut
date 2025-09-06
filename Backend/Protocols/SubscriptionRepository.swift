//
//  SubscriptionRepository.swift
//

import Foundation

public enum SubscriptionPlan: String, Codable, Sendable, CaseIterable {
    case free
    case pro
    case premium
}

public struct SubscriptionStatus: Codable, Sendable, Equatable {
    public var plan: SubscriptionPlan
    public var expiresAt: Date?
    public init(plan: SubscriptionPlan, expiresAt: Date?) {
        self.plan = plan
        self.expiresAt = expiresAt
    }
}

public protocol SubscriptionRepository: Sendable {
    func fetch(for userId: String) async throws -> SubscriptionStatus?
}

public final class LocalSubscriptionRepository: SubscriptionRepository {
    public init() {}
    public func fetch(for userId: String) async throws -> SubscriptionStatus? { .init(plan: .free, expiresAt: nil) }
}
