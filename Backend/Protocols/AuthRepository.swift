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
    /// Sign in (or sign up) using an Apple identity token obtained from ASAuthorization.
    /// - Parameters:
    ///   - idToken: The JWT identity token from Apple (`ASAuthorizationAppleIDCredential.identityToken`).
    ///   - nonce: The **raw** (unhashed) nonce that was passed to Apple. Supabase uses this to
    ///            verify the token was issued for this specific auth request.
    /// - Returns: The authenticated `User`.
    func signInWithApple(idToken: String, nonce: String) async throws -> User
    func signOut() async
    func currentUser() async -> User?
}

public actor LocalAuthRepository: AuthRepository {
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
    public func signInWithApple(idToken: String, nonce: String) async throws -> User {
        // In local mode, simulate a successful Apple sign-in with a mock user.
        let u = User(id: UUID().uuidString, email: "apple-user@local.example")
        self.user = u
        return u
    }
    public func signOut() async { self.user = nil }
    public func currentUser() async -> User? { user }
}
