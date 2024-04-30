//
//  Identity.swift
//  FlagsmithClient
//
//  Created by Tomash Tsiupiak on 6/20/19.
//

import Foundation

/**
 An Identity represents a user stored on the server.
 */
public struct Identity: Decodable, Sendable {
    enum CodingKeys: String, CodingKey {
        case flags
        case traits
    }

    public let flags: [Flag]
    public let traits: [Trait]
}
