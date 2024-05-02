//
//  Trait.swift
//  FlagsmithClient
//
//  Created by Tomash Tsiupiak on 6/20/19.
//

import Foundation

/**
 A Trait represents a value stored against an Identity (user) on the server.
 */
public struct Trait: Codable, Sendable {
    enum CodingKeys: String, CodingKey {
        case key = "trait_key"
        case value = "trait_value"
        case identity
        case identifier
    }

    public let key: String
    /// The underlying value for the `Trait`
    ///
    /// - note: In the future, this can be renamed back to 'value' as major/feature-breaking
    ///         updates are released.
    public var typedValue: TypedValue
    /// The identity of the `Trait` when creating.
    internal let identifier: String?

    public init(key: String, value: TypedValue) {
        self.key = key
        typedValue = value
        identifier = nil
    }

    /// Initializes a `Trait` with an identifier.
    ///
    /// When a `identifier` is provided, the resulting _encoded_ form of the `Trait`
    /// will contain a `identity` key.
    internal init(trait: Trait, identifier: String) {
        key = trait.key
        typedValue = trait.typedValue
        self.identifier = identifier
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        typedValue = try container.decode(TypedValue.self, forKey: .value)
        identifier = nil
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encode(typedValue, forKey: .value)

        if let identifier = identifier {
            var identity = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .identity)
            try identity.encode(identifier, forKey: .identifier)
        }
    }
}

// MARK: - Convenience Initializers

public extension Trait {
    init(key: String, value: Bool) {
        self.key = key
        typedValue = .bool(value)
        identifier = nil
    }

    init(key: String, value: Float) {
        self.key = key
        typedValue = .float(value)
        identifier = nil
    }

    init(key: String, value: Int) {
        self.key = key
        typedValue = .int(value)
        identifier = nil
    }

    init(key: String, value: String) {
        self.key = key
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
