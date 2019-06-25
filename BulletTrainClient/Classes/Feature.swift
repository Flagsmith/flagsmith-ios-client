//
//  Feature.swift
//  BulletTrainClient
//
//  Created by Tomash Tsiupiak on 6/20/19.
//

import Foundation

public struct Feature: Decodable {
  enum CodingKeys: String, CodingKey {
    case name
    case type
    case description
  }
  
  public enum FeatureType: String, Decodable {
    case flag = "FLAG"
    case config = "CONFIG"
  }
  
  public let name: String
  public let type: FeatureType
  public let description: String?
}
