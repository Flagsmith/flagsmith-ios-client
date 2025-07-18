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

typealias CompletionHandler<T> = @Sendable (Result<T, any Error>) -> Void

/// Manage feature flags and remote config across multiple projects,
/// environments and organisations.
public final class Flagsmith: @unchecked Sendable {
    /// Shared singleton client object
    public static let shared: Flagsmith = .init()
    private let apiManager: APIManager
    private let sseManager: SSEManager
    private let analytics: FlagsmithAnalytics

    // The last time we got flags via the API
    private var lastUpdatedAt: Double = 0.0

    // The last identity used for fetching flags
    private var lastUsedIdentity: String?
    // The last result from fetcing flags
    internal var lastFlags: [Flag]?

    var anyFlagStreamContinuation: Any? // AsyncStream<[Flag]>.Continuation? for iOS 13+

    /// Base URL
    ///
    /// The default implementation uses: `https://edge.api.flagsmith.com/api/v1`.
    public var baseURL: URL {
        get { apiManager.baseURL }
        set { apiManager.baseURL = newValue }
    }

    /// Base `URL` used for the event source.
    ///
    /// The default implementation uses: `https://realtime.flagsmith.com/`.
    public var eventSourceBaseURL: URL {
        get { sseManager.baseURL }
        set { sseManager.baseURL = newValue }
    }

    /// Environment Key unique to your organization.
    ///
    /// This value must be provided before any request can succeed.
    public var apiKey: String? {
        get { apiManager.apiKey }
        set {
            apiManager.apiKey = newValue
            sseManager.apiKey = newValue
        }
    }

    /// Is flag analytics enabled?
    public var enableAnalytics: Bool {
        get { analytics.enableAnalytics }
        set { analytics.enableAnalytics = newValue }
    }

    /// Are realtime updates enabled?
    public var enableRealtimeUpdates: Bool {
        get { sseManager.isStarted }
        set {
            if newValue {
                sseManager.stop()
                sseManager.start { [weak self] result in
                    self?.handleSSEResult(result)
                }
            } else {
                sseManager.stop()
            }
        }
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
        sseManager = SSEManager()
        analytics = FlagsmithAnalytics(apiManager: apiManager)
    }

    /// Get all feature flags (flags and remote config) optionally for a specific identity
    ///
    /// - Parameters:
    ///   - identity: ID of the user (optional)
    ///   - transient: If `true`, identity is not persisted
    ///   - completion: Closure with Result which contains array of Flag objects in case of success or Error in case of failure
    public func getFeatureFlags(forIdentity identity: String? = nil,
                                traits: [Trait]? = nil,
                                transient: Bool = false,
                                completion: @Sendable @escaping (Result<[Flag], any Error>) -> Void)
    {
        lastUsedIdentity = identity
        if let identity = identity {
            if let traits = traits {
                apiManager.request(
                    .postTraits(identity: identity, traits: traits, transient: transient)
                ) { (result: Result<Traits, Error>) in
                    switch result {
                    case let .success(result):
                        completion(.success(result.flags))
                    case let .failure(error):
                        self.handleFlagsError(error, completion: completion)
                    }
                }
            } else {
                getIdentity(identity, transient: transient) { result in
                    switch result {
                    case let .success(thisIdentity):
                        self.updateFlagStreamAndLastUpdatedAt(thisIdentity.flags)
                        completion(.success(thisIdentity.flags))
                    case let .failure(error):
                        self.handleFlagsError(error, completion: completion)
                    }
                }
            }
        } else {
            if traits != nil {
                completion(.failure(FlagsmithError.invalidArgument("You must provide an identity to set traits")))
            } else {
                apiManager.request(.getFlags) { [weak self] (result: Result<[Flag], Error>) in
                    switch result {
                    case let .success(flags):
                        // Call updateFlagStream only when iOS 13+
                        self?.updateFlagStreamAndLastUpdatedAt(flags)
                        completion(.success(flags))
                    case let .failure(error):
                        self?.handleFlagsError(error, completion: completion)
                    }
                }
            }
        }
    }

    private func handleFlagsError(_ error: any Error, completion: @Sendable @escaping (Result<[Flag], any Error>) -> Void) {
        if defaultFlags.isEmpty {
            completion(.failure(error))
        } else {
            completion(.success(defaultFlags))
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
    ///   - completion: Closure with Result which contains Trait in case of success or Error in case of failure
    public func setTrait(_ trait: Trait,
                         forIdentity identity: String,
                         completion: @Sendable @escaping (Result<Trait, any Error>) -> Void)
    {
        apiManager.request(.postTrait(trait: trait, identity: identity)) { (result: Result<Trait, Error>) in
            completion(result)
        }
    }

    /// Set user traits in bulk for provided identity
    ///
    /// - Parameters:
    ///   - traits: Traits to be created or updated
    ///   - identity: ID of the user
    ///   - completion: Closure with Result which contains Traits in case of success or Error in case of failure
    public func setTraits(_ traits: [Trait],
                          forIdentity identity: String,
                          completion: @Sendable @escaping (Result<[Trait], any Error>) -> Void)
    {
        apiManager.request(.postTraits(identity: identity, traits: traits)) { (result: Result<Traits, Error>) in
            completion(result.map(\.traits))
        }
    }

    /// Get both feature flags and user traits for the provided identity
    ///
    /// - Parameters:
    ///   - identity: ID of the user
    ///   - transient: If `true`, identity is not persisted
    ///   - completion: Closure with Result which contains Identity in case of success or Error in case of failure
    public func getIdentity(_ identity: String,
                            transient: Bool = false,
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

    private func handleSSEResult(_ result: Result<FlagEvent, any Error>) {
        switch result {
        case let .success(event):
            // Check whether this event is anything new
            if lastUpdatedAt < event.updatedAt {
                // Evict everything fron the cache
                cacheConfig.cache.removeAllCachedResponses()

                // Now we can get the new values, which we can emit to the flagUpdateFlow if used
                getFeatureFlags(forIdentity: lastUsedIdentity) { result in
                    switch result {
                    case let .failure(error):
                        print("Flagsmith - Error getting flags in SSE stream: \(error.localizedDescription)")
                    case .success(_):
                        break
                    }
                }
            }

        case let .failure(error):
            print("handleSSEResult Error in SSE connection: \(error.localizedDescription)")
        }
    }

    func updateFlagStreamAndLastUpdatedAt(_ flags: [Flag]) {
        // Update the flag stream
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            if (flags != lastFlags) {
                flagStreamContinuation?.yield(flags)
            }
        }

        // Update the last updated time if the API is giving us newer data
        if let apiManagerUpdatedAt = apiManager.lastUpdatedAt, apiManagerUpdatedAt > lastUpdatedAt {
            lastUpdatedAt = apiManagerUpdatedAt
        }
        
        // Save the last set of flags we got so that we have something to compare against and only publish changes
        lastFlags = flags
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
