//
//  AuthRepository.swift
//

import Foundation

public struct User: Codable, Equatable, Sendable {
    public var id: String
    public var email: String
}

public protocol AuthRepository: Sendable {
    func signIn(email: String, password: String) async throws -> User
    func signOut() async
    func currentUser() async -> User?
}

public final class LocalAuthRepository: AuthRepository {
    private var user: User?
    public init() {}
    public func signIn(email: String, password: String) async throws -> User {
        let u = User(id: UUID().uuidString, email: email)
        self.user = u
        return u
    }
    public func signOut() async { self.user = nil }
    public func currentUser() async -> User? { user }
}

