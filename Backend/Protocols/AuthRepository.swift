//
//  AuthRepository.swift
//

import Foundation

public struct User: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: String
    public var email: String
}

public enum SignUpOutcome: Sendable, Equatable {
    case signedIn(User)
    case confirmationEmailSent
}

public protocol AuthRepository: Sendable {
    func signIn(email: String, password: String) async throws -> User
    func signUp(email: String, password: String) async throws -> SignUpOutcome
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
    public func signUp(email: String, password: String) async throws -> SignUpOutcome {
        // In local mode, treat sign up as immediate sign in.
        let u = User(id: UUID().uuidString, email: email)
        self.user = u
        return .signedIn(u)
    }
    public func signOut() async { self.user = nil }
    public func currentUser() async -> User? { user }
}
