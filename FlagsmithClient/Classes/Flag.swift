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
  public let value: TypedValue
  public let enabled: Bool

  init(featureName:String, boolValue: Bool, enabled: Bool, featureType:String? = nil, featureDescription:String? = nil) {
    self.init(featureName: featureName, value: TypedValue.bool(boolValue), enabled: enabled, featureType: featureType, featureDescription: featureDescription)
  }

  init(featureName:String, floatValue: Float, enabled: Bool, featureType:String? = nil, featureDescription:String? = nil) {
    self.init(featureName: featureName, value: TypedValue.float(floatValue), enabled: enabled, featureType: featureType, featureDescription: featureDescription)
  }

  init(featureName:String, intValue: Int, enabled: Bool, featureType:String? = nil, featureDescription:String? = nil) {
    self.init(featureName: featureName, value: TypedValue.int(intValue), enabled: enabled, featureType: featureType, featureDescription: featureDescription)
  }

  init(featureName:String, stringValue: String, enabled: Bool, featureType:String? = nil, featureDescription:String? = nil) {
    self.init(featureName: featureName, value: TypedValue.string(stringValue), enabled: enabled, featureType: featureType, featureDescription: featureDescription)
  }

  init(featureName:String, enabled: Bool, featureType:String? = nil, featureDescription:String? = nil) {
    self.init(featureName: featureName, value: TypedValue.null, enabled: enabled, featureType: featureType, featureDescription: featureDescription)
  }

  init(featureName:String, value: TypedValue, enabled: Bool, featureType:String? = nil, featureDescription:String? = nil) {
    self.feature = Feature(name: featureName, type: featureType, description: featureDescription)
    self.value = value
    self.enabled = enabled
  }
}
