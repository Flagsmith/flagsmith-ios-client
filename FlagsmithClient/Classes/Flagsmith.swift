//
//  Flagsmith.swift
//  FlagsmithClient
//
//  Created by Tomash Tsiupiak on 6/20/19.
//

import Foundation

/// Manage feature flags and remote config across multiple projects,
/// environments and organisations.
public class Flagsmith {
  /// Shared singleton client object
  public static let shared = Flagsmith()
  private let apiManager = APIManager()
  private lazy var analytics = FlagsmithAnalytics(apiManager: apiManager)
  
  /// Base URL
  ///
  /// The default implementation uses: `https://edge.api.flagsmith.com/api/v1`.
  public var baseURL: URL {
    set { apiManager.baseURL = newValue }
    get { apiManager.baseURL }
  }
  
  /// API Key unique to your organization.
  ///
  /// This value must be provided before any request can succeed.
  public var apiKey: String? {
    set { apiManager.apiKey = newValue }
    get { apiManager.apiKey }
  }

  /// Is flag analytics enabled?
  public var enableAnalytics: Bool {
    set { analytics.enableAnalytics = newValue }
    get { analytics.enableAnalytics }
  }

  /// How often to send the flag analytics, in seconds
  public var analyticsFlushPeriod: Int {
    set { analytics.flushPeriod = newValue }
    get { analytics.flushPeriod }
  }
  
  /// Default flags to fall back on if an API call fails
  public var defaultFlags: [Flag] = []

  private let CACHED_FLAGS_KEY = "cachedFlags"
  private let NIL_IDENTITY_KEY = "nil-identity"
  
  /// Cached flags to fall back on if an API call fails, by identity
  private var cachedFlags: [String:[Flag]] = [:]
    
  /// Use cached flags as a fallback?
  public var useCache: Bool = true

  private init() {
    if let data = UserDefaults.standard.object(forKey: CACHED_FLAGS_KEY) as? Data {
      if let cachedFlagsObject = try? JSONDecoder().decode([String:[Flag]].self, from: data) {
        self.cachedFlags = cachedFlagsObject
      }
    }
  }
  
  /// Get all feature flags (flags and remote config) optionally for a specific identity
  ///
  /// - Parameters:
  ///   - identity: ID of the user (optional)
  ///   - completion: Closure with Result which contains array of Flag objects in case of success or Error in case of failure
  public func getFeatureFlags(forIdentity identity: String? = nil,
                              completion: @escaping (Result<[Flag], Error>) -> Void) {
    if let identity = identity {
      getIdentity(identity) { (result) in
        switch result {
        case .success(let thisIdentity):
          self.updateCache(flags: thisIdentity.flags, forIdentity: identity)
          completion(.success(self.getFlagsUsingCacheAndDefaults(flags: thisIdentity.flags, forIdentity: identity)))
        case .failure(let error):
          let fallbackFlags = self.getFlagsUsingCacheAndDefaults(flags: [], forIdentity: identity)
          if fallbackFlags.isEmpty {
            completion(.failure(error))
          }
          else {
            completion(.success(fallbackFlags))
          }
        }
      }
    } else {
      apiManager.request(.getFlags) { (result: Result<[Flag], Error>) in
        switch result {
        case .success(let flags):
          self.updateCache(flags: flags, forIdentity: identity)
          completion(.success(self.getFlagsUsingCacheAndDefaults(flags: flags, forIdentity: identity)))
        case .failure(let error):
          let fallbackFlags = self.getFlagsUsingCacheAndDefaults(flags: [], forIdentity: identity)
          if fallbackFlags.isEmpty {
            completion(.failure(error))
          }
          else {
            completion(.success(fallbackFlags))
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
                             completion: @escaping (Result<Bool, Error>) -> Void) {
    analytics.trackEvent(flagName: id)
    getFeatureFlags(forIdentity: identity) { (result) in
      switch result {
      case .success(let flags):
        let hasFlag = flags.contains(where: {$0.feature.name == id && $0.enabled})
        || (self.useCache && self.getCache(forIdentity: identity).contains(where: {$0.feature.name == id && $0.enabled}))
        || self.defaultFlags.contains(where: {$0.feature.name == id && $0.enabled})
        completion(.success(hasFlag))
      case .failure(let error):
        completion(.failure(error))
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
                              completion: @escaping (Result<String?, Error>) -> Void) {
    analytics.trackEvent(flagName: id)
    getFeatureFlags(forIdentity: identity) { (result) in
      switch result {
      case .success(let flags):
        var flag = flags.first(where: {$0.feature.name == id})
        flag = self.getFlagUsingCacheAndDefaults(withID: id, flag: flag, forIdentity: identity)

        completion(.success(flag?.value.stringValue))
      case .failure(let error):
        completion(.failure(error))
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
                                 completion: @escaping (Result<TypedValue?, Error>) -> Void) {
    analytics.trackEvent(flagName: id)
    getFeatureFlags(forIdentity: identity) { (result) in
      switch result {
      case .success(let flags):
        var flag = flags.first(where: {$0.feature.name == id})
        flag = self.getFlagUsingCacheAndDefaults(withID: id, flag: flag, forIdentity: identity)
        completion(.success(flag?.value))
      case .failure(let error):
        completion(.failure(error))
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
                        completion: @escaping (Result<[Trait], Error>) -> Void) {
    getIdentity(identity) { (result) in
      switch result {
      case .success(let identity):
        if let ids = ids {
          let traits = identity.traits.filter({ids.contains($0.key)})
          completion(.success(traits))
        } else {
          completion(.success(identity.traits))
        }
      case .failure(let error):
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
                       completion: @escaping (Result<Trait?, Error>) -> Void) {
    getIdentity(identity) { (result) in
      switch result {
      case .success(let identity):
        let trait = identity.traits.first(where: {$0.key == id})
        completion(.success(trait))
      case .failure(let error):
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
                       completion: @escaping (Result<Trait, Error>) -> Void) {
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
                        completion: @escaping (Result<[Trait], Error>) -> Void) {
    apiManager.request(.postTraits(identity: identity, traits: traits)) { (result: Result<Traits, Error>) in
        completion(result.map(\.traits))
    }
  }
  
  /// Get both feature flags and user traits for the provided identity
  ///
  /// - Parameters:
  ///   - identity: ID of the user
  ///   - completion: Closure with Result which contains Identity in case of success or Error in case of failure
  public func getIdentity(_ identity: String,
                          completion: @escaping (Result<Identity, Error>) -> Void) {
    apiManager.request(.getIdentity(identity: identity)) { (result: Result<Identity, Error>) in
      completion(result)
    }
  }
  
  /// Return a flag for a flag ID and identity, using either the cache (if enabled) or the default flag when the passed flag is nil
  private func getFlagUsingCacheAndDefaults(withID id: String, flag:Flag?, forIdentity identity: String? = nil) -> Flag? {
    var returnFlag = flag
    if returnFlag == nil && self.useCache {
      returnFlag = self.getCache(forIdentity: identity).first(where: {$0.feature.name == id})
    }
    if returnFlag == nil {
      returnFlag = self.defaultFlags.first(where: {$0.feature.name == id})
    }
    
    return returnFlag
  }

  /// Return an array of flag for an identity, including the cached flags (if enabled) and the default flags when they are not already present in the passed array
  private func getFlagsUsingCacheAndDefaults(flags:[Flag], forIdentity identity: String? = nil) -> [Flag] {
    var returnFlags:[Flag] = []
    returnFlags.append(contentsOf: flags)
    
    if useCache {
      for flag in getCache(forIdentity: identity) {
        if !returnFlags.contains(where: { $0.feature.name == flag.feature.name }) {
          if flag.value != .null {
            returnFlags.append(flag)
          }
        }
      }
    }

    for flag in defaultFlags {
      if !returnFlags.contains(where: { $0.feature.name == flag.feature.name }) {
        if flag.value != .null {
          returnFlags.append(flag)
        }
      }
    }
    
    return returnFlags
  }

  /// Update the cache for an identity for a set of flags, and store
  private func updateCache(flags:[Flag], forIdentity identity: String? = nil) {
    for flag in flags {
      var identityCachedFlags = getCache(forIdentity: identity)
      identityCachedFlags.removeAll(where: {$0.feature.name == flag.feature.name})
      identityCachedFlags.append(flag)
      self.cachedFlags[identity ?? NIL_IDENTITY_KEY] = identityCachedFlags
    }
      
    if let data = try? JSONEncoder().encode(cachedFlags) {
        UserDefaults.standard.set(data, forKey: CACHED_FLAGS_KEY)
    }
  }
  
  /// Get the cached flags for an identity
  private func getCache(forIdentity identity: String? = nil) -> [Flag] {
    return self.cachedFlags[identity ?? NIL_IDENTITY_KEY] ?? []
  }
}
