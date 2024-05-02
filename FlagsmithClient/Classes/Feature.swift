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

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(description, forKey: .description)
    }
}
