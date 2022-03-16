//
//  FlagsmithClientTestCase.swift
//  FlagsmithClientTests
//
//  Created by Richard Piazza on 3/16/22.
//

import XCTest
@testable import FlagsmithClient

class FlagsmithClientTestCase: XCTestCase {
    
    let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    
    let decoder: JSONDecoder = .init()
}
