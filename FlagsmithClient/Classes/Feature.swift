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
public struct Feature: Decodable {
  enum CodingKeys: String, CodingKey {
    case name
    case type
    case description
  }
  
  /// The name of the feature
  public let name: String
  public let type: String?
  public let description: String?
}
