//
//  Flag.swift
//  BulletTrainClient
//
//  Created by Tomash Tsiupiak on 6/20/19.
//

import Foundation

public struct Flag: Decodable {
  enum CodingKeys: String, CodingKey {
    case feature
    case value = "feature_state_value"
    case enabled
  }
  
  public let feature: Feature
  public let value: String?
  public let enabled: Bool
}
