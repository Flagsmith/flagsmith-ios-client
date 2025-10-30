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
    // The last result from fetching flags
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
                        self.handleFlagsErrorForIdentity(error, identity: identity, completion: completion)
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
        // Priority: 1. Try cached flags, 2. Fall back to default flags, 3. Return error
        
        // First, try to get cached flags if caching is enabled
        if cacheConfig.useCache {
            if let cachedFlags = getCachedFlags() {
                completion(.success(cachedFlags))
                return
            }
        }
        
        // If no cached flags available, try default flags
        if !defaultFlags.isEmpty {
            completion(.success(defaultFlags))
        } else {
            completion(.failure(error))
        }
    }
    
    private func handleFlagsErrorForIdentity(_ error: any Error, identity: String, completion: @Sendable @escaping (Result<[Flag], any Error>) -> Void) {
        // Priority: 1. Try cached flags for identity, 2. Try general cached flags, 3. Fall back to default flags, 4. Return error
        
        // First, try to get cached flags for the specific identity if caching is enabled
        if cacheConfig.useCache {
            if let cachedFlags = getCachedFlags(forIdentity: identity) {
                completion(.success(cachedFlags))
                return
            }
            
            // If no identity-specific cache, try general flags cache
            if let cachedFlags = getCachedFlags() {
                completion(.success(cachedFlags))
                return
            }
        }
        
        // If no cached flags available, try default flags
        if !defaultFlags.isEmpty {
            completion(.success(defaultFlags))
        } else {
            completion(.failure(error))
        }
    }
    
    private func getCachedFlags() -> [Flag]? {
        let cache = cacheConfig.cache
        
        // Create request for general flags
        let request = URLRequest(url: baseURL.appendingPathComponent("flags/"))
        
        // Check if we have a cached response
        if let cachedResponse = cache.cachedResponse(for: request) {
            // Check if cache is still valid based on TTL
            if isCacheValid(cachedResponse: cachedResponse) {
                do {
                    let flags = try JSONDecoder().decode([Flag].self, from: cachedResponse.data)
                    return flags
                } catch {
                    print("Flagsmith - Failed to decode cached flags: \(error.localizedDescription)")
                    return nil
                }
            }
        }
        
        return nil
    }
    
    private func getCachedFlags(forIdentity identity: String) -> [Flag]? {
        let cache = cacheConfig.cache
        
        // Create request for identity-specific flags
        let identityURL = baseURL.appendingPathComponent("identities/")
        guard var components = URLComponents(url: identityURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.queryItems = [URLQueryItem(name: "identifier", value: identity)]
        
        guard let url = components.url else { return nil }
        let request = URLRequest(url: url)
        
        // Check if we have a cached response
        if let cachedResponse = cache.cachedResponse(for: request) {
            // Check if cache is still valid based on TTL
            if isCacheValid(cachedResponse: cachedResponse) {
                do {
                    let identity = try JSONDecoder().decode(Identity.self, from: cachedResponse.data)
                    return identity.flags
                } catch {
                    print("Flagsmith - Failed to decode cached identity flags: \(error.localizedDescription)")
                    return nil
                }
            }
        }
        
        return nil
    }
    
    private func isCacheValid(cachedResponse: CachedURLResponse) -> Bool {
        guard let httpResponse = cachedResponse.response as? HTTPURLResponse else { return false }
        
        // Check if we have a cache control header
        if let cacheControl = httpResponse.allHeaderFields["Cache-Control"] as? String {
            // First check for no-cache and no-store directives (case-insensitive, token-aware)
            if hasNoCacheDirective(in: cacheControl) {
                return false
            }
            
            if let maxAge = extractMaxAge(from: cacheControl) {
                // Check if cache is still valid based on max-age
                if let dateString = httpResponse.allHeaderFields["Date"] as? String,
                   let date = HTTPURLResponse.dateFormatter.date(from: dateString) {
                    let age = Date().timeIntervalSince(date)
                    return age < maxAge
                }
            }
        }
        
        // If no cache control, validate against configured TTL
        if cacheConfig.cacheTTL > 0 {
            if let dateString = httpResponse.allHeaderFields["Date"] as? String,
               let date = HTTPURLResponse.dateFormatter.date(from: dateString) {
                let age = Date().timeIntervalSince(date)
                return age < cacheConfig.cacheTTL
            }
            // No Date header, be conservative
            return false
        }
        // TTL of 0 means infinite
        
        return true

    }
    
    private func extractMaxAge(from cacheControl: String) -> TimeInterval? {
        let components = cacheControl.split(separator: ",")
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("max-age=") {
                let maxAgeString = String(trimmed.dropFirst(8))
                return TimeInterval(maxAgeString)
            }
        }
        return nil
    }
    
    private func hasNoCacheDirective(in cacheControl: String) -> Bool {
        let components = cacheControl.split(separator: ",")
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            let directiveTokens = trimmed.split(separator: "=").first?.split(separator: ";").first
            guard let directiveToken = directiveTokens else { continue }
            
            let directive = directiveToken.trimmingCharacters(in: .whitespaces).lowercased()
            if directive == "no-cache" || directive == "no-store" {
                return true
            }
        }
        return false
    }
}

// MARK: - HTTPURLResponse Extensions

extension HTTPURLResponse {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        return formatter
    }()
}

// MARK: - Public API Methods

extension Flagsmith {
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
