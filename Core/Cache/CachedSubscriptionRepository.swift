//
//  CachedSubscriptionRepository.swift
//
//  A caching decorator for any `SubscriptionRepository` implementation.
//
//  Subscription status is cached with a shorter expiry (default 30 minutes) so
//  entitlement changes surface quickly while still avoiding redundant network calls
//  during normal usage.
//
//  Usage in DIContainer:
//  ```swift
//  let subscriptionRepo: SubscriptionRepository
//  if config.featureFlags.enableCaching {
//      subscriptionRepo = CachedSubscriptionRepository(remote: SupabaseSubscriptionRepository())
//  } else {
//      subscriptionRepo = SupabaseSubscriptionRepository()
//  }
//  ```
//

import Foundation

/// An actor-based caching decorator for any `SubscriptionRepository`.
///
/// Wraps the remote repository and serves cached `SubscriptionStatus` values
/// when they are still fresh. Expired entries trigger a transparent remote fetch.
public actor CachedSubscriptionRepository: SubscriptionRepository {

    // MARK: - Dependencies

    /// The real repository that queries the backend.
    private let remote: SubscriptionRepository

    /// The cache manager instance.
    private let cache: CacheManager

    /// How long subscription data stays fresh.
    private let expiry: CacheExpiry

    // MARK: - Init

    /// Creates a cached wrapper around `remote`.
    ///
    /// - Parameters:
    ///   - remote: The real repository (e.g., `SupabaseSubscriptionRepository`).
    ///   - cache: The cache manager. Defaults to the shared singleton.
    ///   - expiry: How long subscription data stays fresh. Defaults to `CacheConfig.subscriptionExpiry` (30 min).
    public init(remote: SubscriptionRepository,
                cache: CacheManager = .shared,
                expiry: CacheExpiry = CacheConfig.subscriptionExpiry) {
        self.remote = remote
        self.cache = cache
        self.expiry = expiry
    }

    // MARK: - SubscriptionRepository

    /// Fetches subscription status, returning a cached copy when available and fresh.
    ///
    /// Flow:
    /// 1. Check the cache for key `"subscription_{userId}"`.
    /// 2. If a non-expired entry exists, return it immediately.
    /// 3. Otherwise, fetch from the remote repository.
    /// 4. On success, write the result to the cache and return it.
    public func fetch(for userId: String) async throws -> SubscriptionStatus? {
        let key = CacheKeys.subscription(userId)

        // Try cache first
        if let cached: SubscriptionStatus = await cache.get(forKey: key) {
            #if DEBUG
            print("[CachedSubscriptionRepository] Cache HIT for \(key)")
            #endif
            return cached
        }

        #if DEBUG
        print("[CachedSubscriptionRepository] Cache MISS for \(key) -- fetching remote")
        #endif

        // Fetch from remote
        let status = try await remote.fetch(for: userId)

        // Cache the result
        if let status {
            await cache.set(status, forKey: key, expiry: expiry)
        }

        return status
    }

    // MARK: - Manual Refresh

    /// Forces a fresh fetch from the remote, bypassing and replacing the cache.
    ///
    /// Useful after a purchase completes or when you know the subscription state
    /// has just changed.
    ///
    /// ```swift
    /// if let repo = container.subscriptionRepository as? CachedSubscriptionRepository {
    ///     let fresh = try await repo.forceRefresh(for: userId)
    /// }
    /// ```
    public func forceRefresh(for userId: String) async throws -> SubscriptionStatus? {
        let key = CacheKeys.subscription(userId)

        // Invalidate existing cache
        await cache.remove(forKey: key)

        // Fetch fresh
        let status = try await remote.fetch(for: userId)
        if let status {
            await cache.set(status, forKey: key, expiry: expiry)
        }

        #if DEBUG
        print("[CachedSubscriptionRepository] Force-refreshed \(key)")
        #endif

        return status
    }
}
