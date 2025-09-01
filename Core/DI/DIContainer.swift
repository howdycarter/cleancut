//
//  DIContainer.swift
//

import Foundation

public struct DIContainer: Sendable {
    public var config: AppConfig
    public var authRepository: AuthRepository
    public var userRepository: UserRepository

    public init(config: AppConfig,
                authRepository: AuthRepository,
                userRepository: UserRepository) {
        self.config = config
        self.authRepository = authRepository
        self.userRepository = userRepository
    }
}

public extension DIContainer {
    static func makeDefault(config: AppConfig = .default) -> DIContainer {
        let auth = LocalAuthRepository()
        let user = LocalUserRepository(auth: auth)
        return DIContainer(config: config, authRepository: auth, userRepository: user)
    }
}

private struct DIContainerKey: Sendable {}

import SwiftUI

private struct DIKey: EnvironmentKey {
    static let defaultValue: DIContainer = .makeDefault()
}

public extension EnvironmentValues {
    var container: DIContainer {
        get { self[DIKey.self] }
        set { self[DIKey.self] = newValue }
    }
}

public extension View {
    func inject(_ container: DIContainer) -> some View { environment(\.container, container) }
}

