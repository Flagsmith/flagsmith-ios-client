//
//  Trait.swift
//  BulletTrainClient
//
//  Created by Tomash Tsiupiak on 6/20/19.
//

import Foundation

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
