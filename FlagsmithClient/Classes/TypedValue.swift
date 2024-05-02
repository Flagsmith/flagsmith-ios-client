//
//  TypedValue.swift
//  FlagsmithClient
//
//  Created by Richard Piazza on 3/16/22.
//

import Foundation

/// A value associated to a `Flag` or `Trait`
public enum TypedValue: Equatable, Sendable {
    case bool(Bool)
    case float(Float)
    case int(Int)
    case string(String)
    case null
}

extension TypedValue: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }

        if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }

        if let value = try? container.decode(Float.self) {
            self = .float(value)
            return
        }

        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }

        if container.decodeNil() {
            self = .null
            return
        }

        let context = DecodingError.Context(
            codingPath: [],
            debugDescription: "No decodable `TypedValue` value found."
        )
        throw DecodingError.valueNotFound((any Decodable).self, context)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .bool(value):
            try container.encode(value)
        case let .float(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

extension TypedValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .bool(value): return "\(value)"
        case let .float(value): return "\(value)"
        case let .int(value): return "\(value)"
        case let .string(value): return value
        case .null: return ""
        }
    }
}

// Provides backwards compatible API for `UnknownTypeValue`
// (eg: `Flag.value.intValue?`, `Flag.value.stringValue?`, `Flag.value.floatValue?`)
public extension TypedValue {
    /// Attempts to cast the associated value as an `Int`
    @available(*, deprecated, message: "Switch on `TypedValue` to retrieve the associated data type.")
    var intValue: Int? {
        switch self {
        case let .bool(value): return value ? 1 : 0
        case let .float(value): return Int(value)
        case let .int(value): return value
        case let .string(value): return Int(value)
        case .null: return nil
        }
    }

    /// Attempts to cast the associated value as an `Float`
    @available(*, deprecated, message: "Switch on `TypedValue` to retrieve the associated data type.")
    var floatValue: Float? {
        switch self {
        case let .bool(value): return value ? 1.0 : 0.0
        case let .float(value): return value
        case let .int(value): return Float(value)
        case let .string(value): return Float(value)
        case .null: return nil
        }
    }

    /// Attempts to cast the associated value as an `String`
    @available(*, deprecated, message: "Switch on `TypedValue` to retrieve the associated data type.")
    var stringValue: String? {
        switch self {
        case .null: return nil
        default: return description
        }
    }
}
