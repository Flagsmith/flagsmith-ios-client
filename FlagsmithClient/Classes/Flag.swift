//
//  Flag.swift
//  FlagsmithClient
//
//  Created by Tomash Tsiupiak on 6/20/19.
//

import Foundation

/**
A Flag represents a feature flag on the server.
*/
public struct Flag: Decodable {
  enum CodingKeys: String, CodingKey {
    case feature
    case value = "feature_state_value"
    case enabled
  }
  
  public let feature: Feature
  public let value: UnknownTypeValue?
  public let enabled: Bool
}
