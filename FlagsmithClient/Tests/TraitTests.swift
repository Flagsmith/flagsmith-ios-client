//
//  TraitTests.swift
//  FlagsmithClientTests
//
//  Created by Richard Piazza on 3/16/22.
//

@testable import FlagsmithClient
import XCTest

/// Tests `Trait`
final class TraitTests: FlagsmithClientTestCase {
    func testDecodeTraits() throws {
        let json = """
        [
            {
                "trait_key": "is_orange",
                "trait_value": false
            },
            {
                "trait_key": "pi",
                "trait_value": 3.14
            },
            {
                "trait_key": "miles_per_hour",
                "trait_value": 88
            },
            {
                "trait_key": "message",
                "trait_value": "Welcome"
            },
            {
                "trait_key": "deprecated",
                "trait_value": null
            }
        ]
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let traits = try decoder.decode([Trait].self, from: data)
        XCTAssertEqual(traits.count, 5)

        let boolTrait = try XCTUnwrap(traits.first(where: { $0.key == "is_orange" }))
        XCTAssertEqual(boolTrait.typedValue, .bool(false))

        let floatTrait = try XCTUnwrap(traits.first(where: { $0.key == "pi" }))
        XCTAssertEqual(floatTrait.typedValue, .float(3.14))

        let intTrait = try XCTUnwrap(traits.first(where: { $0.key == "miles_per_hour" }))
        XCTAssertEqual(intTrait.typedValue, .int(88))

        let stringTrait = try XCTUnwrap(traits.first(where: { $0.key == "message" }))
        XCTAssertEqual(stringTrait.typedValue, .string("Welcome"))

        let nullTrait = try XCTUnwrap(traits.first(where: { $0.key == "deprecated" }))
        XCTAssertEqual(nullTrait.typedValue, .null)
    }

    func testEncodeTraits() throws {
        let wrappedTrait = Trait(key: "dark_mode", value: .bool(true))
        let trait = Trait(trait: wrappedTrait, identifier: "theme_settings")
        let data = try encoder.encode(trait)
        let json = try """
        {
          "identity" : {
            "identifier" : "theme_settings"
          },
          "trait_key" : "dark_mode",
          "trait_value" : true
        }
        """.json(using: .utf8)
        XCTAssertEqual(try data.json(), json)
    }

    func testEncodeTransientTraits() throws {
        let wrappedTrait = Trait(key: "dark_mode", value: .bool(true), transient: true)
        let trait = Trait(trait: wrappedTrait, identifier: "theme_settings")
        let data = try encoder.encode(trait)
        let json = try """
        {
          "identity" : {
            "identifier" : "theme_settings"
          },
          "trait_key" : "dark_mode",
          "trait_value" : true,
          "transient" : true
        }
        """.json(using: .utf8)
        XCTAssertEqual(try data.json(), json)
    }

    func testEncodeTransientIdentity() throws {
        let wrappedTrait = Trait(key: "dark_mode", value: .bool(true))
        let trait = Trait(trait: wrappedTrait, identifier: "transient_identity", transient: true)
        let data = try encoder.encode(trait)
        let json = try """
        {
          "identity" : {
            "identifier" : "transient_identity",
            "transient" : true
          },
          "trait_key" : "dark_mode",
          "trait_value" : true,
        }
        """.json(using: .utf8)
        XCTAssertEqual(try data.json(), json)
    }
}
