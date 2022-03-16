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
public struct Trait: Codable {
  enum CodingKeys: String, CodingKey {
    case key = "trait_key"
    case value = "trait_value"
  }
  
  public let key: String
  public var value: UnknownTypeValue?
  
  public init(key: String, value: UnknownTypeValue?) {
    self.key = key
    self.value = value
  }

    public init(key: String, value: Int) {
      self.key = key
      self.value = UnknownTypeValue(value: value)
    }

    public init(key: String, value: String) {
      self.key = key
      self.value = UnknownTypeValue(value: value)
    }

    public init(key: String, value: Float) {
      self.key = key
      self.value = UnknownTypeValue(value: value)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        switch value {
        case .int(let value):
            try container.encode(value, forKey: .value)
        case .string(let value):
            try container.encode(value, forKey: .value)
        case .float(let value):
            try container.encode(value, forKey: .value)
        case .null:
            break
        case .none:
            break
        }        
    }
}

/**
A PostTrait represents a structure to set a new trait, with the Trait fields and the identity.
*/
public struct PostTrait: Codable {
  enum CodingKeys: String, CodingKey {
    case key = "trait_key"
    case value = "trait_value"
    case identity = "identity"
  }
  
  public let key: String
  public var value: UnknownTypeValue?
  public var identity: IdentityStruct
  
  public struct IdentityStruct: Codable {
    public var identifier: String
            
    public enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
    }
    
    public init(identifier: String) {
      self.identifier = identifier
    }
  }
    
  public init(key: String, value: UnknownTypeValue?, identifier:String) {
    self.key = key
    self.value = value
    self.identity = IdentityStruct(identifier: identifier)
  }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encode(identity, forKey: .identity)
        switch value {
        case .int(let value):
            try container.encode(value, forKey: .value)
        case .string(let value):
            try container.encode(value, forKey: .value)
        case .float(let value):
            try container.encode(value, forKey: .value)
        case .null:
            break
        case .none:
            break
        }
    }
}
