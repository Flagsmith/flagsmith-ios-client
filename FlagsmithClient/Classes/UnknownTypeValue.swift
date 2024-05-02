//
//  UnknownTypeValue.swift
//  FlagsmithClient
//
//  Created by Daniel Wichett on 30/06/2021.
//

import Foundation

/**
 An UnknownTypeValue represents a value which can have a variable type
 */
@available(*, deprecated, renamed: "TypedValue")
public enum UnknownTypeValue: Decodable, Sendable {
    case int(Int), string(String), float(Float), null

    public init(from decoder: any Decoder) throws {
        if let int = try? decoder.singleValueContainer().decode(Int.self) {
            self = .int(int)
            return
        }

        if let string = try? decoder.singleValueContainer().decode(String.self) {
            self = .string(string)
            return
        }

        if let float = try? decoder.singleValueContainer().decode(Float.self) {
            self = .float(float)
            return
        }

        self = .null
    }

    public enum UnknownTypeError: Error {
        case missingValue
    }

    public var intValue: Int? {
        switch self {
        case let .int(value): return value
        case let .string(value): return Int(value)
        case let .float(value): return Int(value)
        case .null: return nil
        }
    }

    public var stringValue: String? {
        switch self {
        case let .int(value): return String(value)
        case let .string(value): return value
        case let .float(value): return String(value)
        case .null: return nil
        }
    }

    public var floatValue: Float? {
        switch self {
        case let .int(value): return Float(value)
        case let .string(value): return Float(value)
        case let .float(value): return value
        case .null: return nil
        }
    }
}
