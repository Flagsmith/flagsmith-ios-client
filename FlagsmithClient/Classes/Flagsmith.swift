//
//  Flagsmith.swift
//  FlagsmithClient
//
//  Created by Tomash Tsiupiak on 6/20/19.
//

import Foundation

public class Flagsmith {
  /// Shared singleton client object
  public static let shared = Flagsmith()
  private let apiManager = APIManager()
  private lazy var analytics = FlagsmithAnalytics(apiManager: apiManager)
  
  /// Base URL
  public var baseURL: URL {
    set { apiManager.baseURL = newValue }
    get { apiManager.baseURL }
  }
  
  /// API Key
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

  private init() {}
  
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
        case .success(let identity):
          completion(.success(identity.flags))
        case .failure(let error):
          completion(.failure(error))
        }
      }
    } else {
      apiManager.request(.getFlags) { (result: Result<[Flag], Error>) in
        completion(result)
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
        let value = flags.first(where: {$0.feature.name == id})?.value
        completion(.success(value?.stringValue))
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
        let value = flags.first(where: {$0.feature.name == id})?.value
        completion(.success(value))
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
}
