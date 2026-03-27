//
//  CacheManager.swift
//
//  A thread-safe, actor-based caching layer that uses an in-memory dictionary for
//  speed and UserDefaults for persistence across app launches.
//
//  ---
//
//  HOW TO ADD CACHING TO A NEW FEATURE (3-step guide)
//  ==================================================
//
//  Suppose you have a `PostsRepository` protocol and you want to cache post lists.
//
//  **Step 1** — Define a key convention (just a string constant):
//
//      extension CacheKeys {
//          static func postList(page: Int) -> String { "posts_list_page_\(page)" }
//          static func postDetail(id: String) -> String { "post_detail_\(id)" }
//      }
//
//  **Step 2** — (Optional) Add a default expiry in CacheConfig:
//
//      extension CacheConfig {
//          static let postsExpiry: CacheExpiry = .minutes(10)
//      }
//
//  **Step 3** — Write a tiny cached wrapper (decorator pattern):
//
//      final class CachedPostsRepository: PostsRepository, @unchecked Sendable {
//          // -- NO, we use actor isolation instead! See CachedProfileRepository for the pattern.
//      }
//
//      // Better: use the same pattern as CachedProfileRepository:
//
//      actor CachedPostsRepository: PostsRepository {
//          private let remote: PostsRepository
//          private let cache: CacheManager
//
//          init(remote: PostsRepository, cache: CacheManager) {
//              self.remote = remote
//              self.cache = cache
//          }
//
//          func fetchPosts(page: Int) async throws -> [Post] {
//              let key = CacheKeys.postList(page: page)
//              if let cached: [Post] = await cache.get(forKey: key) {
//                  return cached
//              }
//              let posts = try await remote.fetchPosts(page: page)
//              await cache.set(posts, forKey: key, expiry: CacheConfig.postsExpiry)
//              return posts
//          }
//      }
//
//  **That's it.** Register it in DIContainer like any other repository, optionally
//  gated behind `FeatureFlags.enableCaching`.
//
//  ---
//
//  PATTERN-BASED INVALIDATION
//  ==========================
//
//  You can invalidate groups of related keys at once using wildcard patterns:
//
//      await cache.invalidate(matching: "posts_*")       // all post-related cache
//      await cache.invalidate(matching: "*_page_1")      // page 1 of every list
//      await cache.invalidate(matching: "*settings*")    // anything containing "settings"
//
//  AUTO-INVALIDATION ON LOGOUT
//  ===========================
//
//  Call `CacheManager.shared.removeAll()` when the user signs out. The provided
//  `CachedProfileRepository` already listens for `authStatusDidChange` if you
//  prefer automatic behavior. See the integration in DIContainer.
//

import Foundation

// MARK: - CacheKeys Namespace

/// A namespace for cache key conventions. Extend this enum to add keys for new features.
///
/// ```swift
/// extension CacheKeys {
///     static func myFeatureData(id: String) -> String { "myfeature_\(id)" }
/// }
/// ```
public enum CacheKeys {
    /// Profile for a given user ID.
    public static func profile(_ userId: String) -> String { "profile_\(userId)" }

    /// Subscription status for a given user ID.
    public static func subscription(_ userId: String) -> String { "subscription_\(userId)" }
}

// MARK: - CacheManager

/// The heart of the caching system.
///
/// `CacheManager` is an `actor`, so all access is automatically serialized
/// without any manual locking. It maintains a two-tier storage strategy:
///
/// 1. **In-memory dictionary** — zero-cost lookups for hot data.
/// 2. **UserDefaults persistence** — survives app restarts.
///
/// On every `get`, the manager checks the in-memory tier first. On a miss it
/// falls through to UserDefaults, re-hydrates the in-memory tier, and returns.
/// Expired entries are lazily pruned on access.
public actor CacheManager: CacheStorage {

    // MARK: - Singleton

    /// Shared instance used throughout the app. Created once, lives forever.
    public static let shared = CacheManager()

    // MARK: - Storage

    /// Fast in-memory tier. Keys map to raw JSON `Data`.
    private var memoryStore: [String: Data] = [:]

    /// Persistent tier backed by a dedicated UserDefaults suite.
    private let defaults: UserDefaults

    /// The key prefix used to namespace all entries.
    private let prefix: String

    // MARK: - Init

    /// Creates a `CacheManager` with the given UserDefaults suite and key prefix.
    ///
    /// - Parameters:
    ///   - suiteName: The UserDefaults suite. Defaults to `CacheConfig.userDefaultsSuiteName`.
    ///   - prefix: The key prefix. Defaults to `CacheConfig.keyPrefix`.
    public init(suiteName: String = CacheConfig.userDefaultsSuiteName,
                prefix: String = CacheConfig.keyPrefix) {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
        self.prefix = prefix
    }

    // MARK: - Public API — CacheStorage conformance

    /// Retrieves a cached value of type `T` for the given key.
    ///
    /// Returns `nil` when:
    /// - No entry exists for the key.
    /// - The entry exists but has expired (it is also removed automatically).
    /// - The stored data cannot be decoded into `T`.
    ///
    /// ```swift
    /// if let profile: Profile = await cache.get(forKey: CacheKeys.profile(userId)) {
    ///     // Use cached profile
    /// }
    /// ```
    public func get<T: Codable & Sendable>(forKey key: String) async -> T? {
        let prefixedKey = prefixed(key)

        // Tier 1: in-memory
        if let data = memoryStore[prefixedKey] {
            if let entry = decode(CacheEntry<T>.self, from: data) {
                if entry.isExpired {
                    removeInternal(prefixedKey: prefixedKey)
                    return nil
                }
                return entry.value
            }
            // Decode failure — stale/corrupted data; remove it.
            removeInternal(prefixedKey: prefixedKey)
            return nil
        }

        // Tier 2: UserDefaults
        guard let data = defaults.data(forKey: prefixedKey) else { return nil }
        guard let entry = decode(CacheEntry<T>.self, from: data) else {
            removeInternal(prefixedKey: prefixedKey)
            return nil
        }
        if entry.isExpired {
            removeInternal(prefixedKey: prefixedKey)
            return nil
        }

        // Re-hydrate memory tier
        memoryStore[prefixedKey] = data
        return entry.value
    }

    /// Stores a value under the given key with the specified expiry.
    ///
    /// The value is written to both the in-memory dictionary and UserDefaults
    /// simultaneously.
    ///
    /// ```swift
    /// await cache.set(profile, forKey: CacheKeys.profile(userId), expiry: .hours(1))
    /// ```
    public func set<T: Codable & Sendable>(_ value: T, forKey key: String, expiry: CacheExpiry) async {
        let prefixedKey = prefixed(key)
        let entry = CacheEntry(value: value, expiry: expiry)
        guard let data = encode(entry) else { return }

        memoryStore[prefixedKey] = data
        defaults.set(data, forKey: prefixedKey)
    }

    /// Removes the cached value for a single key.
    ///
    /// ```swift
    /// await cache.remove(forKey: CacheKeys.profile(userId))
    /// ```
    public func remove(forKey key: String) async {
        removeInternal(prefixedKey: prefixed(key))
    }

    /// Removes **all** entries managed by this CacheManager.
    ///
    /// Call this on user sign-out to ensure no stale personal data remains.
    ///
    /// ```swift
    /// await CacheManager.shared.removeAll()
    /// ```
    public func removeAll() async {
        // Clear memory
        let keysToRemove = memoryStore.keys.filter { $0.hasPrefix(prefix) }
        for k in keysToRemove {
            memoryStore.removeValue(forKey: k)
        }
        // Clear UserDefaults
        let allDefaults = defaults.dictionaryRepresentation()
        for key in allDefaults.keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
    }

    /// Removes all entries whose keys match a simple wildcard pattern.
    ///
    /// The `pattern` parameter supports `*` as a wildcard:
    /// - `"profile_*"` — matches keys starting with `"profile_"`.
    /// - `"*_detail"` — matches keys ending with `"_detail"`.
    /// - `"*user*"` — matches keys containing `"user"`.
    /// - `"exact"` — matches only the key `"exact"`.
    ///
    /// Note: The pattern is matched against the **unprefixed** key (i.e., the key
    /// you used when calling `set`). The internal prefix is handled automatically.
    ///
    /// ```swift
    /// await cache.invalidate(matching: "profile_*")  // all profiles
    /// ```
    public func invalidate(matching pattern: String) async {
        let allKeys = collectAllKeys()
        for prefixedKey in allKeys {
            let userKey = String(prefixedKey.dropFirst(prefix.count))
            if matchesWildcard(userKey, pattern: pattern) {
                removeInternal(prefixedKey: prefixedKey)
            }
        }
    }

    // MARK: - Convenience

    /// Returns `true` if a non-expired entry exists for the given key.
    ///
    /// This performs a type-erased check by looking for raw data. It does **not**
    /// validate that the data can be decoded into any particular type.
    public func contains(key: String) -> Bool {
        let prefixedKey = prefixed(key)
        return memoryStore[prefixedKey] != nil || defaults.data(forKey: prefixedKey) != nil
    }

    /// Returns a snapshot of all user-facing keys currently in the cache
    /// (both memory and disk), without the internal prefix.
    public func allKeys() -> [String] {
        collectAllKeys().map { String($0.dropFirst(prefix.count)) }
    }

    // MARK: - Internals

    /// Adds the configured prefix to a user-provided key.
    private func prefixed(_ key: String) -> String {
        prefix + key
    }

    /// Gathers all keys from both memory and disk that start with the prefix.
    private func collectAllKeys() -> Set<String> {
        var keys = Set(memoryStore.keys.filter { $0.hasPrefix(prefix) })
        let diskKeys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }
        keys.formUnion(diskKeys)
        return keys
    }

    /// Removes a single prefixed key from both tiers.
    private func removeInternal(prefixedKey: String) {
        memoryStore.removeValue(forKey: prefixedKey)
        defaults.removeObject(forKey: prefixedKey)
    }

    /// Matches a key against a simple wildcard pattern.
    ///
    /// - `"*"` matches everything.
    /// - `"abc*"` matches keys starting with `"abc"`.
    /// - `"*abc"` matches keys ending with `"abc"`.
    /// - `"*abc*"` matches keys containing `"abc"`.
    /// - `"abc"` matches only `"abc"` exactly.
    private func matchesWildcard(_ key: String, pattern: String) -> Bool {
        // Exact match (no wildcard)
        guard pattern.contains("*") else { return key == pattern }

        let parts = pattern.split(separator: "*", omittingEmptySubsequences: false).map(String.init)

        // Single wildcard patterns (most common)
        if parts.count == 2 {
            let before = parts[0]
            let after = parts[1]
            if before.isEmpty && after.isEmpty { return true }          // "*"
            if before.isEmpty { return key.hasSuffix(after) }           // "*suffix"
            if after.isEmpty { return key.hasPrefix(before) }           // "prefix*"
            return key.hasPrefix(before) && key.hasSuffix(after)        // "pre*suf"
        }

        // Multi-wildcard: greedy sequential match
        var remaining = key[key.startIndex...]
        for (index, part) in parts.enumerated() {
            if part.isEmpty { continue }
            if index == 0 {
                guard remaining.hasPrefix(part) else { return false }
                remaining = remaining.dropFirst(part.count)
            } else if index == parts.count - 1 {
                guard remaining.hasSuffix(part) else { return false }
            } else {
                guard let range = remaining.range(of: part) else { return false }
                remaining = remaining[range.upperBound...]
            }
        }
        return true
    }

    // MARK: - Codable Helpers

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private func encode<T: Encodable>(_ value: T) -> Data? {
        do {
            return try encoder.encode(value)
        } catch {
            #if DEBUG
            print("[CacheManager] Encode error for \(T.self): \(error)")
            #endif
            return nil
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            #if DEBUG
            print("[CacheManager] Decode error for \(T.self): \(error)")
            #endif
            return nil
        }
    }
}
