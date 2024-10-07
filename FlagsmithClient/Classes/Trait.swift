//
//  Trait.swift
//  FlagsmithClient
//
//  Created by Tomash Tsiupiak on 6/20/19.
//

import Foundation

/**
 A `Trait` represents a key-value pair used by Flagsmith to segment an `Identity`.
 A `Trait` with `transient` set to `true` is not stored in Flagsmith backend.
 */
public struct Trait: Codable, Sendable {
    enum CodingKeys: String, CodingKey {
        case key = "trait_key"
        case value = "trait_value"
        case transient
        case identity
        case identifier
    }

    public let key: String
    /// The underlying value for the `Trait`
    ///
    /// - note: In the future, this can be renamed back to 'value' as major/feature-breaking
    ///         updates are released.
    public var typedValue: TypedValue
    public let transient: Bool
    /// The identity of the `Trait` when creating.
    internal let identifier: String?
    
    public init(key: String, value: TypedValue, transient: Bool = false) {
        self.key = key
        self.transient = transient
        typedValue = value
        identifier = nil
    }

    /// Initializes a `Trait` with an identifier.
    ///
    /// When a `identifier` is provided, the resulting _encoded_ form of the `Trait`
    /// will contain a `identity` key.
    internal init(trait: Trait, identifier: String) {
        key = trait.key
        transient = trait.transient
        typedValue = trait.typedValue
        self.identifier = identifier
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.transient) {
            transient = try container.decode(Bool.self, forKey: .transient)
        } else {
            transient = false
        }
        key = try container.decode(String.self, forKey: .key)
        typedValue = try container.decode(TypedValue.self, forKey: .value)
        identifier = nil
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encode(typedValue, forKey: .value)

        if let identifier = identifier {
            // Assume call to `/api/v1/traits` SDK endpoint
            // (used to persist traits for previously persisted identities).
            // Flagsmith does not process the `transient` attribute in this case,
            // so we don't need it here.
            var identity = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .identity)
            try identity.encode(identifier, forKey: .identifier)
        } else {
            try container.encode(transient, forKey: .transient)
        }
    }
}

// MARK: - Convenience Initializers

public extension Trait {
    init(key: String, value: Bool, transient: Bool = false) {
        self.key = key
        self.transient = transient
        typedValue = .bool(value)
        identifier = nil
    }

    init(key: String, value: Float, transient: Bool = false) {
        self.key = key
        self.transient = transient
        typedValue = .float(value)
        identifier = nil
    }

    init(key: String, value: Int, transient: Bool = false) {
        self.key = key
        self.transient = transient
        typedValue = .int(value)
        identifier = nil
    }

    init(key: String, value: String, transient: Bool = false) {
        self.key = key
        self.transient = transient
        typedValue = .string(value)
        identifier = nil
    }
}

// MARK: - Deprecations

public extension Trait {
    @available(*, deprecated, renamed: "typedValue")
    var value: String {
        get { typedValue.description }
        set { typedValue = .string(newValue) }
    }
}

/**
 A PostTrait represents a structure to set a new trait, with the Trait fields and the identity.
 */
@available(*, deprecated)
public struct PostTrait: Codable {
    enum CodingKeys: String, CodingKey {
        case key = "trait_key"
        case value = "trait_value"
        case identity
    }

    public let key: String
    public var value: String
    public var identity: IdentityStruct

    public struct IdentityStruct: Codable {
        public var identifier: String

        public enum CodingKeys: String, CodingKey {
            case identifier
        }

        public init(identifier: String) {
            self.identifier = identifier
        }
    }

    public init(key: String, value: String, identifier: String) {
        self.key = key
        self.value = value
        identity = IdentityStruct(identifier: identifier)
    }
}
