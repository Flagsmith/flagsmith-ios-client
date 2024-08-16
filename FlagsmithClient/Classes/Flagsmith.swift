//
//  Flagsmith.swift
//  FlagsmithClient
//
//  Created by Tomash Tsiupiak on 6/20/19.
//

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Manage feature flags and remote config across multiple projects,
/// environments and organisations.
public final class Flagsmith: @unchecked Sendable {
    /// Shared singleton client object
    public static let shared: Flagsmith = .init()
    private let apiManager: APIManager
    private let analytics: FlagsmithAnalytics

    /// Base URL
    ///
    /// The default implementation uses: `https://edge.api.flagsmith.com/api/v1`.
    public var baseURL: URL {
        get { apiManager.baseURL }
        set { apiManager.baseURL = newValue }
    }

    /// API Key unique to your organization.
    ///
    /// This value must be provided before any request can succeed.
    public var apiKey: String? {
        get { apiManager.apiKey }
        set { apiManager.apiKey = newValue }
    }

    /// Is flag analytics enabled?
    public var enableAnalytics: Bool {
        get { analytics.enableAnalytics }
        set { analytics.enableAnalytics = newValue }
    }

    /// How often to send the flag analytics, in seconds
    public var analyticsFlushPeriod: Int {
        get { analytics.flushPeriod }
        set { analytics.flushPeriod = newValue }
    }

    /// Default flags to fall back on if an API call fails
    private var _defaultFlags: [Flag] = []
    public var defaultFlags: [Flag] {
        get {
            apiManager.propertiesSerialAccessQueue.sync { _defaultFlags }
        }
        set {
            apiManager.propertiesSerialAccessQueue.sync {
                _defaultFlags = newValue
            }
        }
    }

    /// Configuration class for the cache settings
    private var _cacheConfig: CacheConfig = .init()
    public var cacheConfig: CacheConfig {
        get {
            apiManager.propertiesSerialAccessQueue.sync { _cacheConfig }
        }
        set {
            apiManager.propertiesSerialAccessQueue.sync {
                _cacheConfig = newValue
            }
        }
    }

    private init() {
        apiManager = APIManager()
        analytics = FlagsmithAnalytics(apiManager: apiManager)
    }

    /// Get all feature flags (flags and remote config) optionally for a specific identity
    ///
    /// - Parameters:
    ///   - identity: ID of the user (optional)
    ///   - completion: Closure with Result which contains array of Flag objects in case of success or Error in case of failure
    public func getFeatureFlags(forIdentity identity: String? = nil,
                                completion: @Sendable @escaping (Result<[Flag], any Error>) -> Void)
    {
        if let identity = identity {
            getIdentity(identity) { result in
                switch result {
                case let .success(thisIdentity):
                    completion(.success(thisIdentity.flags))
                case let .failure(error):
                    if self.defaultFlags.isEmpty {
                        completion(.failure(error))
                    } else {
                        completion(.success(self.defaultFlags))
                    }
                }
            }
        } else {
            apiManager.request(.getFlags) { (result: Result<[Flag], Error>) in
                switch result {
                case let .success(flags):
                    completion(.success(flags))
                case let .failure(error):
                    if self.defaultFlags.isEmpty {
                        completion(.failure(error))
                    } else {
                        completion(.success(self.defaultFlags))
                    }
                }
            }
        }
    }

    /// Check feature exists and is enabled optionally for a specific identity
    ///
    /// - Parameters:
    ///   - id: ID of the feature
    ///   - identity: ID of the user (optional)
    ///   - completion: Closure with Result which contains Bool in case of success or Error in case of failure
    public func hasFeatureFlag(withID id: String,
                               forIdentity identity: String? = nil,
                               completion: @Sendable @escaping (Result<Bool, any Error>) -> Void)
    {
        analytics.trackEvent(flagName: id)
        getFeatureFlags(forIdentity: identity) { result in
            switch result {
            case let .success(flags):
                let hasFlag = flags.contains(where: { $0.feature.name == id && $0.enabled })
                completion(.success(hasFlag))
            case let .failure(error):
                if self.defaultFlags.contains(where: { $0.feature.name == id && $0.enabled }) {
                    completion(.success(true))
                } else {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Get remote config value optionally for a specific identity
    ///
    /// - Parameters:
    ///   - id: ID of the feature
    ///   - identity: ID of the user (optional)
    ///   - completion: Closure with Result which String in case of success or Error in case of failure
    @available(*, deprecated, renamed: "getValueForFeature(withID:forIdentity:completion:)")
    public func getFeatureValue(withID id: String,
                                forIdentity identity: String? = nil,
                                completion: @Sendable @escaping (Result<String?, any Error>) -> Void)
    {
        analytics.trackEvent(flagName: id)
        getFeatureFlags(forIdentity: identity) { result in
            switch result {
            case let .success(flags):
                let flag = flags.first(where: { $0.feature.name == id })
                completion(.success(flag?.value.stringValue))
            case let .failure(error):
                if let flag = self.getFlagUsingDefaults(withID: id, forIdentity: identity) {
                    completion(.success(flag.value.stringValue))
                } else {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Get remote config value optionally for a specific identity
    ///
    /// - Parameters:
    ///   - id: ID of the feature
    ///   - identity: ID of the user (optional)
    ///   - completion: Closure with Result of `TypedValue` in case of success or `Error` in case of failure
    public func getValueForFeature(withID id: String,
                                   forIdentity identity: String? = nil,
                                   completion: @Sendable @escaping (Result<TypedValue?, any Error>) -> Void)
    {
        analytics.trackEvent(flagName: id)
        getFeatureFlags(forIdentity: identity) { result in
            switch result {
            case let .success(flags):
                let flag = flags.first(where: { $0.feature.name == id })
                completion(.success(flag?.value))
            case let .failure(error):
                if let flag = self.getFlagUsingDefaults(withID: id, forIdentity: identity) {
                    completion(.success(flag.value))
                } else {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Get all user traits for provided identity. Optionally filter results with a list of keys
    ///
    /// - Parameters:
    ///   - ids: IDs of the trait (optional)
    ///   - identity: ID of the user
    ///   - completion: Closure with Result which contains array of Trait objects in case of success or Error in case of failure
    public func getTraits(withIDS ids: [String]? = nil,
                          forIdentity identity: String,
                          completion: @Sendable @escaping (Result<[Trait], any Error>) -> Void)
    {
        getIdentity(identity) { result in
            switch result {
            case let .success(identity):
                if let ids = ids {
                    let traits = identity.traits.filter { ids.contains($0.key) }
                    completion(.success(traits))
                } else {
                    completion(.success(identity.traits))
                }
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    /// Get user trait for provided identity and trait key
    ///
    /// - Parameters:
    ///   - id: ID of the trait
    ///   - identity: ID of the user
    ///   - completion: Closure with Result which contains Trait in case of success or Error in case of failure
    public func getTrait(withID id: String,
                         forIdentity identity: String,
                         completion: @Sendable @escaping (Result<Trait?, any Error>) -> Void)
    {
        getIdentity(identity) { result in
            switch result {
            case let .success(identity):
                let trait = identity.traits.first(where: { $0.key == id })
                completion(.success(trait))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    /// Set user trait for provided identity
    ///
    /// - Parameters:
    ///   - trait: Trait to be created or updated
    ///   - identity: ID of the user
    ///   - transient: Should the identity be transient (default: false)
    ///   - completion: Closure with Result which contains Trait in case of success or Error in case of failure
    public func setTrait(_ trait: Trait,
                         forIdentity identity: String,
                         transient: Bool = false,
                         completion: @Sendable @escaping (Result<Trait, any Error>) -> Void)
    {
        apiManager.request(.postTrait(trait: trait, identity: identity, transient: transient)) { (result: Result<Trait, Error>) in
            completion(result)
        }
    }

    /// Set user traits in bulk for provided identity
    ///
    /// - Parameters:
    ///   - traits: Traits to be created or updated
    ///   - identity: ID of the user
    ///   - transient: Should the identity be transient (default: false)
    ///   - completion: Closure with Result which contains Traits in case of success or Error in case of failure
    public func setTraits(_ traits: [Trait],
                          forIdentity identity: String,
                          transient: Bool = false,
                          completion: @Sendable @escaping (Result<[Trait], any Error>) -> Void)
    {
        apiManager.request(.postTraits(identity: identity, traits: traits, transient: transient)) { (result: Result<Traits, Error>) in
            completion(result.map(\.traits))
        }
    }

    /// Get both feature flags and user traits for the provided identity
    ///
    /// - Parameters:
    ///   - identity: ID of the user
    ///   - completion: Closure with Result which contains Identity in case of success or Error in case of failure
    public func getIdentity(_ identity: String,
                            completion: @Sendable @escaping (Result<Identity, any Error>) -> Void)
    {
        apiManager.request(.getIdentity(identity: identity)) { (result: Result<Identity, Error>) in
            completion(result)
        }
    }

    /// Return a flag for a flag ID from the default flags.
    private func getFlagUsingDefaults(withID id: String, forIdentity _: String? = nil) -> Flag? {
        return defaultFlags.first(where: { $0.feature.name == id })
    }
}

public final class CacheConfig {
    /// Cache to use when enabled, defaults to the shared app cache
    public var cache: URLCache = .shared

    /// Use cached flags as a fallback?
    public var useCache: Bool = false

    /// TTL for the cache in seconds, default of 0 means infinite
    public var cacheTTL: Double = 0

    /// Skip API if there is a cache available
    public var skipAPI: Bool = false
}
