//
//  CachedProfileRepository.swift
//
//  A decorator that wraps any `ProfileRepository` implementation with transparent
//  caching via `CacheManager`.
//
//  Behaviour:
//  - `fetchProfile`:  cache hit (fresh) -> return cached  |  miss/expired -> fetch remote -> cache -> return
//  - `upsertProfile`: update remote -> update cache immediately (write-through)
//  - `uploadAvatar`:  upload remote -> invalidate profile cache so the next fetch picks up the new URL
//
//  Usage in DIContainer:
//  ```swift
//  let profile: ProfileRepository
//  if config.featureFlags.enableCaching {
//      profile = CachedProfileRepository(remote: SupabaseProfileRepository(), cache: .shared)
//  } else {
//      profile = SupabaseProfileRepository()
//  }
//  ```
//

import Foundation

/// An actor-based caching decorator for any `ProfileRepository`.
///
/// Because this type is an `actor` it is inherently `Sendable` and thread-safe
/// without any manual locking. It conforms to `ProfileRepository`, so it can be
/// used as a drop-in replacement anywhere the protocol is expected.
public actor CachedProfileRepository: ProfileRepository {

    // MARK: - Dependencies

    /// The underlying (remote or local) repository that actually talks to the backend.
    private let remote: ProfileRepository

    /// The cache manager used for storing / retrieving profile data.
    private let cache: CacheManager

    /// The expiry applied to cached profiles.
    private let expiry: CacheExpiry

    // MARK: - Init

    /// Creates a cached wrapper around `remote`.
    ///
    /// - Parameters:
    ///   - remote: The real repository implementation (e.g., `SupabaseProfileRepository`).
    ///   - cache: The cache manager. Defaults to the shared singleton.
    ///   - expiry: How long profiles stay fresh. Defaults to `CacheConfig.profileExpiry`.
    public init(remote: ProfileRepository,
                cache: CacheManager = .shared,
                expiry: CacheExpiry = CacheConfig.profileExpiry) {
        self.remote = remote
        self.cache = cache
        self.expiry = expiry
    }

    // MARK: - ProfileRepository

    /// Fetches a profile, returning a cached copy when available and fresh.
    ///
    /// Flow:
    /// 1. Check the cache for key `"profile_{userId}"`.
    /// 2. If a non-expired entry exists, return it immediately.
    /// 3. Otherwise, fetch from the remote repository.
    /// 4. On success, write the result to the cache and return it.
    public func fetchProfile(for userId: String) async throws -> Profile? {
        let key = CacheKeys.profile(userId)

        // Try cache first
        if let cached: Profile = await cache.get(forKey: key) {
            #if DEBUG
            print("[CachedProfileRepository] Cache HIT for \(key)")
            #endif
            return cached
        }

        #if DEBUG
        print("[CachedProfileRepository] Cache MISS for \(key) -- fetching remote")
        #endif

        // Fetch from remote
        let profile = try await remote.fetchProfile(for: userId)

        // Cache the result (even nil is useful -- but we only cache non-nil)
        if let profile {
            await cache.set(profile, forKey: key, expiry: expiry)
        }

        return profile
    }

    /// Updates the profile remotely, then writes the updated value through to the cache.
    ///
    /// This ensures the cache is always consistent with the latest known state,
    /// avoiding stale reads after an edit.
    public func upsertProfile(_ profile: Profile) async throws {
        // Write to remote first (source of truth)
        try await remote.upsertProfile(profile)

        // Write-through: update cache immediately
        let key = CacheKeys.profile(profile.id)
        await cache.set(profile, forKey: key, expiry: expiry)

        #if DEBUG
        print("[CachedProfileRepository] Cache UPDATED for \(key)")
        #endif
    }

    /// Uploads an avatar remotely, then invalidates the profile cache so the
    /// next `fetchProfile` picks up the new avatar URL.
    public func uploadAvatar(data: Data, for userId: String, contentType: String) async throws -> URL {
        // Upload to remote
        let url = try await remote.uploadAvatar(data: data, for: userId, contentType: contentType)

        // Invalidate the profile cache -- the avatar URL has changed
        let key = CacheKeys.profile(userId)
        await cache.remove(forKey: key)

        #if DEBUG
        print("[CachedProfileRepository] Cache INVALIDATED for \(key) after avatar upload")
        #endif

        return url
    }
}
