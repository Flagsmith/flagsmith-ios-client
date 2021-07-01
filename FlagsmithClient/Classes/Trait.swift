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
  public var value: String
  
  public init(key: String, value: String) {
    self.key = key
    self.value = value
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
  public var value: String
  var identity: IdentityStruct
  
  struct IdentityStruct: Codable {
    var identifier: String
            
    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
    }
    public init(identifier: String) {
      self.identifier = identifier
    }
  }
    
  public init(key: String, value: String, identifier:String) {
    self.key = key
    self.value = value
    self.identity = IdentityStruct(identifier: identifier)
  }
}
