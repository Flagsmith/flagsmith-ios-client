//
//  FlagEvent.swift
//  FlagsmithClient
//
//  Created by Gareth Reese on 13/09/2024.
//

import Foundation

public struct FlagEvent: Codable, Sendable {
    enum CodingKeys: String, CodingKey {
        case updatedAt = "updated_at"
    }
    
    public let updatedAt: Double
}
