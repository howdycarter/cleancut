//
//  CacheInvalidationObserver.swift
//
//  Listens for app-wide events (e.g., sign-out) and automatically clears the
//  cache so no stale personal data persists across user sessions.
//
//  Setup: Call `CacheInvalidationObserver.shared.startListening()` once at app
//  launch (e.g., in your App's `init` or `RootView.onAppear`). It is safe to
//  call multiple times -- only the first call registers observers.
//
//  The observer listens for:
//  - `Notification.Name.userDidSignOut` — clears the entire cache.
//  - `Notification.Name.authStatusDidChange` — clears the cache when the
//    notification's `userInfo` contains `"signedOut": true`.
//

import Foundation

/// Bridges NotificationCenter events to `CacheManager.removeAll()`.
///
/// This is a plain class (not an actor) because NotificationCenter callbacks
/// run on the posting thread and we immediately hop to the actor via `Task`.
public final class CacheInvalidationObserver: Sendable {

    // MARK: - Singleton

    /// Shared observer instance. Retains itself through NotificationCenter.
    public static let shared = CacheInvalidationObserver()

    // MARK: - State

    /// The cache manager whose contents are cleared on sign-out events.
    private let cache: CacheManager

    /// Tracks whether we have already registered observers.
    private nonisolated(unsafe) var isListening = false

    // MARK: - Init

    /// Creates an observer targeting the given cache manager.
    public init(cache: CacheManager = .shared) {
        self.cache = cache
    }

    // MARK: - Public API

    /// Registers NotificationCenter observers. Safe to call more than once.
    ///
    /// Call this once at app startup:
    /// ```swift
    /// // In your App struct or RootView
    /// CacheInvalidationObserver.shared.startListening()
    /// ```
    public func startListening() {
        guard !isListening else { return }
        isListening = true

        let center = NotificationCenter.default

        // Direct sign-out notification
        center.addObserver(forName: .userDidSignOut, object: nil, queue: nil) { [cache] _ in
            Task {
                await cache.removeAll()
                #if DEBUG
                print("[CacheInvalidationObserver] Cache cleared on userDidSignOut")
                #endif
            }
        }

        // Auth status change -- check for sign-out payload
        center.addObserver(forName: .authStatusDidChange, object: nil, queue: nil) { [cache] notification in
            let signedOut = notification.userInfo?["signedOut"] as? Bool ?? false
            if signedOut {
                Task {
                    await cache.removeAll()
                    #if DEBUG
                    print("[CacheInvalidationObserver] Cache cleared on authStatusDidChange (signedOut)")
                    #endif
                }
            }
        }
    }
}
