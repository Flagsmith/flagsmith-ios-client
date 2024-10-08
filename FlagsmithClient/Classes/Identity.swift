//
//  Identity.swift
//  FlagsmithClient
//
//  Created by Tomash Tsiupiak on 6/20/19.
//

import Foundation

/**
 An `Identity` represents a set of user data used for flag evaluation.
 An `Identity` with `transient` set to `true` is not stored in Flagsmith backend.
 */
public struct Identity: Decodable, Sendable {
    enum CodingKeys: String, CodingKey {
        case flags
        case traits
        case transient
    }

    public let flags: [Flag]
    public let traits: [Trait]
    public let transient: Bool
}
