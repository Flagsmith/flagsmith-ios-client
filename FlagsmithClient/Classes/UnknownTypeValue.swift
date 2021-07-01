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
enum UnknownTypeValue: Decodable {
    
    case int(Int), string(String), float(Float)
    
    init(from decoder: Decoder) throws {
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

        throw UnknownTypeError.missingValue
    }
    
    enum UnknownTypeError:Error {
        case missingValue
    }
    
    var intValue: Int? {
        switch self {
        case .int(let value): return value
        case .string(let value): return Int(value)
        case .float(let value): return Int(value)
        }
    }

    var stringValue: String? {
        switch self {
        case .int(let value): return String(value)
        case .string(let value): return value
        case .float(let value): return String(value)
        }
    }

    var floatValue: Float? {
        switch self {
        case .int(let value): return Float(value)
        case .string(let value): return Float(value)
        case .float(let value): return value
        }
    }
}
