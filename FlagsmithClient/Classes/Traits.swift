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
}
