//
//  Flagsmith+Concurrency.swift
//  FlagsmithClient
//
//  Created by Richard Piazza on 3/10/22.
//

import Foundation

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *)
public extension Flagsmith {
    var flagStreamContinuation: AsyncStream<[Flag]>.Continuation? {
        get {
            return anyFlagStreamContinuation as? AsyncStream<[Flag]>.Continuation
        }
        set {
            anyFlagStreamContinuation = newValue
        }
    }

    var flagStream: AsyncStream<[Flag]> {
        AsyncStream { continuation in
            anyFlagStreamContinuation = continuation
        }
    }

    /// Get all feature flags (flags and remote config) optionally for a specific identity
    ///
    /// - Parameters:
    ///   - identity: ID of the user (optional)
    /// - returns: Collection of Flag objects
    func getFeatureFlags(forIdentity identity: String? = nil) async throws -> [Flag] {
        try await withCheckedThrowingContinuation { continuation in
            getFeatureFlags(forIdentity: identity) { result in
                switch result {
                case let .failure(error):
                    continuation.resume(throwing: error)
                case let .success(value):
                    continuation.resume(returning: value)
                }
            }
        }
    }

    /// Check feature exists and is enabled optionally for a specific identity
    ///
    /// - Parameters:
    ///   - id: ID of the feature
    ///   - identity: ID of the user (optional)
    /// - returns: Bool value of the feature
    func hasFeatureFlag(withID id: String, forIdentity identity: String? = nil) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            hasFeatureFlag(withID: id, forIdentity: identity) { result in
                switch result {
                case let .failure(error):
                    continuation.resume(throwing: error)
                case let .success(value):
                    continuation.resume(returning: value)
                }
            }
        }
    }

    /// Get remote config value optionally for a specific identity
    ///
    /// - Parameters:
    ///   - id: ID of the feature
    ///   - identity: ID of the user (optional)
    /// - returns: String value of the feature if available
    @available(*, deprecated, renamed: "getValueForFeature(withID:forIdentity:)")
    func getFeatureValue(withID id: String, forIdentity identity: String? = nil) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            getFeatureValue(withID: id, forIdentity: identity) { result in
                switch result {
                case let .failure(error):
                    continuation.resume(throwing: error)
                case let .success(value):
                    continuation.resume(returning: value)
                }
            }
        }
    }

    /// Get remote config value optionally for a specific identity
    ///
    /// - Parameters:
    ///   - id: ID of the feature
    ///   - identity: ID of the user (optional)
    /// - returns: String value of the feature if available
    func getValueForFeature(withID id: String, forIdentity identity: String? = nil) async throws -> TypedValue? {
        try await withCheckedThrowingContinuation { continuation in
            getValueForFeature(withID: id, forIdentity: identity) { result in
                switch result {
                case let .failure(error):
                    continuation.resume(throwing: error)
                case let .success(value):
                    continuation.resume(returning: value)
                }
            }
        }
    }

    /// Get all user traits for provided identity. Optionally filter results with a list of keys
    ///
    /// - Parameters:
    ///   - ids: IDs of the trait (optional)
    ///   - identity: ID of the user
    /// - returns: Collection of Trait objects
    func getTraits(withIDS ids: [String]? = nil, forIdentity identity: String) async throws -> [Trait] {
      
      var dataTask: URLSessionTask?
      
      return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
          dataTask = getTraits(withIDS: ids, forIdentity: identity) { result in
            switch result {
            case let .failure(error):
              continuation.resume(throwing: error)
            case let .success(value):
              continuation.resume(returning: value)
            }
          }
        }
      } onCancel: {
        dataTask?.cancel()
      }
    }

    /// Get user trait for provided identity and trait key
    ///
    /// - Parameters:
    ///   - id: ID of the trait
    ///   - identity: ID of the user
    /// - returns: Optional Trait if found.
    func getTrait(withID id: String, forIdentity identity: String) async throws -> Trait? {
        try await withCheckedThrowingContinuation { continuation in
            getTrait(withID: id, forIdentity: identity) { result in
                switch result {
                case let .failure(error):
                    continuation.resume(throwing: error)
                case let .success(value):
                    continuation.resume(returning: value)
                }
            }
        }
    }

    /// Set user trait for provided identity
    ///
    /// - Parameters:
    ///   - trait: Trait to be created or updated
    ///   - identity: ID of the user
    /// - returns: The Trait requested to be set.
    @discardableResult func setTrait(_ trait: Trait, forIdentity identity: String) async throws -> Trait {
        try await withCheckedThrowingContinuation { continuation in
            setTrait(trait, forIdentity: identity) { result in
                switch result {
                case let .failure(error):
                    continuation.resume(throwing: error)
                case let .success(value):
                    continuation.resume(returning: value)
                }
            }
        }
    }

    /// Set user traits in bulk for provided identity
    ///
    /// - Parameters:
    ///   - trait: Traits to be created or updated
    ///   - identity: ID of the user
    /// - returns: The Traits requested to be set.
    @discardableResult func setTraits(_ traits: [Trait], forIdentity identity: String) async throws -> [Trait] {
      
      var dataTask: URLSessionTask?
      
      return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
          dataTask = setTraits(traits, forIdentity: identity) { result in
            switch result {
            case let .failure(error):
              continuation.resume(throwing: error)
            case let .success(value):
              continuation.resume(returning: value)
            }
          }
        }
      } onCancel: {
        dataTask?.cancel()
      }
    }

    /// Get both feature flags and user traits for the provided identity
    ///
    /// - Parameters:
    ///   - identity: ID of the user
    /// - returns: Identity matching the requested ID.
    func getIdentity(_ identity: String) async throws -> Identity {
        try await withCheckedThrowingContinuation { continuation in
            getIdentity(identity) { result in
                switch result {
                case let .failure(error):
                    continuation.resume(throwing: error)
                case let .success(value):
                    continuation.resume(returning: value)
                }
            }
        }
    }
}
