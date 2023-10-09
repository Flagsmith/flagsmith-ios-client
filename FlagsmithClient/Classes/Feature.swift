//
//  Feature.swift
//  FlagsmithClient
//
//  Created by Tomash Tsiupiak on 6/20/19.
//

import Foundation

/**
 A Feature represents a flag or remote configuration value on the server.
 */
public struct Feature: Codable, Sendable {
  enum CodingKeys: String, CodingKey {
    case name
    case type
    case description
  }
  
  /// The name of the feature
  public let name: String
  public let type: String?
  public let description: String?
  
  init(name: String, type: String?, description: String?) {
    self.name = name
    self.type = type
    self.description = description
  }
  
  public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(self.name, forKey: .name)
      try container.encodeIfPresent(self.type, forKey: .type)
      try container.encodeIfPresent(self.description, forKey: .description)
  }
}
