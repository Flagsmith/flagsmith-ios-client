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
public struct Flag: Codable, Sendable, Equatable {
    enum CodingKeys: String, CodingKey {
        case feature
        case value = "feature_state_value"
        case enabled
        case variant
        case metadata
    }

    private struct Metadata: Codable {
        let experiment: Experiment?
    }

    public let feature: Feature
    public let value: TypedValue
    public let enabled: Bool
    /// The key of the multivariate option served to the identity, if any.
    public let variant: String?
    /// The running experiment the flag was evaluated under, for an identity.
    public let experiment: Experiment?

    public init(featureName: String, boolValue: Bool, enabled: Bool,
                featureType: String? = nil, featureDescription: String? = nil)
    {
        self.init(featureName: featureName, value: TypedValue.bool(boolValue), enabled: enabled,
                  featureType: featureType, featureDescription: featureDescription)
    }

    public init(featureName: String, floatValue: Float, enabled: Bool,
                featureType: String? = nil, featureDescription: String? = nil)
    {
        self.init(featureName: featureName, value: TypedValue.float(floatValue), enabled: enabled,
                  featureType: featureType, featureDescription: featureDescription)
    }

    public init(featureName: String, intValue: Int, enabled: Bool,
                featureType: String? = nil, featureDescription: String? = nil)
    {
        self.init(featureName: featureName, value: TypedValue.int(intValue), enabled: enabled,
                  featureType: featureType, featureDescription: featureDescription)
    }

    public init(featureName: String, stringValue: String, enabled: Bool,
                featureType: String? = nil, featureDescription: String? = nil)
    {
        self.init(featureName: featureName, value: TypedValue.string(stringValue), enabled: enabled,
                  featureType: featureType, featureDescription: featureDescription)
    }

    public init(featureName: String, enabled: Bool,
                featureType: String? = nil, featureDescription: String? = nil)
    {
        self.init(featureName: featureName, value: TypedValue.null, enabled: enabled,
                  featureType: featureType, featureDescription: featureDescription)
    }

    public init(featureName: String, value: TypedValue, enabled: Bool,
                featureType: String? = nil, featureDescription: String? = nil)
    {
        feature = Feature(name: featureName, type: featureType, description: featureDescription)
        self.value = value
        self.enabled = enabled
        variant = nil
        experiment = nil
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        feature = try container.decode(Feature.self, forKey: .feature)
        value = try container.decode(TypedValue.self, forKey: .value)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        variant = try container.decodeIfPresent(String.self, forKey: .variant)
        experiment = (try? container.decodeIfPresent(Metadata.self, forKey: .metadata))?.experiment
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(feature, forKey: .feature)
        try container.encode(value, forKey: .value)
        try container.encode(enabled, forKey: .enabled)
        try container.encodeIfPresent(variant, forKey: .variant)
        if let experiment = experiment {
            try container.encode(Metadata(experiment: experiment), forKey: .metadata)
        }
    }
    
    public static func == (lhs: Flag, rhs: Flag) -> Bool {
        return lhs.feature.name == rhs.feature.name &&
            lhs.value == rhs.value &&
            lhs.enabled == rhs.enabled
    }
}
