//
//  ReconnectionDelay.swift
//  FlagsmithClient
//
//  Created by Gareth Reese on 18/09/2024.
//

import Foundation

class ReconnectionDelay {
    private var attempt: Int
    private let maxDelay: TimeInterval
    private let initialDelay: TimeInterval
    private let multiplier: Double

    init(initialDelay: TimeInterval = 1.0, maxDelay: TimeInterval = 60.0, multiplier: Double = 2.0) {
        attempt = 0
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.multiplier = multiplier
    }

    func nextDelay() -> TimeInterval {
        let delay = min(initialDelay * pow(multiplier, Double(attempt)), maxDelay)
        attempt += 1
        return delay
    }

    func reset() {
        attempt = 0
    }
}
