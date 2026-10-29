//
//  Experiment.swift
//  FlagsmithClient
//

import Foundation

/**
 An `Experiment` is the running experiment a `Flag` was evaluated under, for an identity.
 */
public struct Experiment: Codable, Sendable, Equatable {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case inExperiment = "in_experiment"
    }

    public let id: Int
    public let name: String
    /// Whether the identity is enrolled in the experiment.
    public let inExperiment: Bool
}
