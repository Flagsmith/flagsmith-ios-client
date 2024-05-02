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
public struct Flag: Codable, Sendable {
    enum CodingKeys: String, CodingKey {
        case feature
        case value = "feature_state_value"
        case enabled
    }

    public let feature: Feature
    public let value: TypedValue
    public let enabled: Bool

    public init(featureName: String, boolValue: Bool, enabled: Bool,
        featureType: String? = nil, featureDescription: String? = nil) {
        self.init(featureName: featureName, value: TypedValue.bool(boolValue), enabled: enabled,
                    featureType: featureType, featureDescription: featureDescription)
    }

    public init(featureName: String, floatValue: Float, enabled: Bool, featureType: String? = nil, featureDescription: String? = nil) {
        self.init(featureName: featureName, value: TypedValue.float(floatValue), enabled: enabled, featureType: featureType, featureDescription: featureDescription)
    }

    public init(featureName: String, intValue: Int, enabled: Bool, featureType: String? = nil, featureDescription: String? = nil) {
        self.init(featureName: featureName, value: TypedValue.int(intValue), enabled: enabled, featureType: featureType, featureDescription: featureDescription)
    }

    public init(featureName: String, stringValue: String, enabled: Bool, featureType: String? = nil, featureDescription: String? = nil) {
        self.init(featureName: featureName, value: TypedValue.string(stringValue), enabled: enabled, featureType: featureType, featureDescription: featureDescription)
    }

    public init(featureName: String, enabled: Bool, featureType: String? = nil, featureDescription: String? = nil) {
        self.init(featureName: featureName, value: TypedValue.null, enabled: enabled, featureType: featureType, featureDescription: featureDescription)
    }

    public init(featureName: String, value: TypedValue, enabled: Bool, featureType: String? = nil, featureDescription: String? = nil) {
        feature = Feature(name: featureName, type: featureType, description: featureDescription)
        self.value = value
        self.enabled = enabled
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(feature, forKey: .feature)
        try container.encode(value, forKey: .value)
        try container.encode(enabled, forKey: .enabled)
    }
}
