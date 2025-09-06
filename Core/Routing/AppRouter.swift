//
//  AppRouter.swift
//

import SwiftUI

public enum AppRoute: Hashable {
    case home
    case settings
    case detail(id: String)
    case notifications
    case paywall
}

@MainActor
public final class AppRouter: ObservableObject {
    @Published public var path: NavigationPath = .init()

    public init() {}

    public func reset() { path.removeLast(path.count) }
    public func push(_ route: AppRoute) { path.append(route) }
}
