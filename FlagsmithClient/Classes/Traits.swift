//
//  Traits.swift
//  FlagsmithClient
//
//  Created by Rob Valdes on 07/02/23.
//

import Foundation

/**
 A Traits object represent a collection of different `Trait`s stored against the same Identity (user) on the server.
 */
public struct Traits: Codable, Sendable {
    public let traits: [Trait]
    public let identifier: String?
    public let flags: [Flag]
    public let transient: Bool
    
    init(traits: [Trait], identifier: String?, flags: [Flag] = [], transient: Bool = false) {
        self.traits = traits
        self.identifier = identifier
        self.flags = flags
        self.transient = transient
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(traits, forKey: .traits)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(transient, forKey: .transient)
    }
}
