//
//  UserRepository.swift
//

import Foundation

public protocol UserRepository: Sendable {
    func fetchCurrentUserProfile() async throws -> User
}

public final class LocalUserRepository: UserRepository {
    private let auth: AuthRepository
    public init(auth: AuthRepository) { self.auth = auth }
    public func fetchCurrentUserProfile() async throws -> User {
        if let u = await auth.currentUser() { return u }
        throw NSError(domain: "UserRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "No signed-in user."])
    }
}

