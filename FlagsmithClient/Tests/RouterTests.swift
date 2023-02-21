//
//  RouterTests.swift
//  FlagsmithClientTests
//
//  Created by Richard Piazza on 3/21/22.
//

import XCTest
@testable import FlagsmithClient

final class RouterTests: FlagsmithClientTestCase {
    
    let baseUrl = URL(string: "https://edge.api.flagsmith.com/api/v1")
    let apiKey = "E71DC632-82BA-4522-82F3-D39FB6DC90AC"
    
    func testGetFlagsRequest() throws {
        let url = try XCTUnwrap(baseUrl)
        let route = Router.getFlags
        let request = try route.request(baseUrl: url, apiKey: apiKey)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString, "https://edge.api.flagsmith.com/api/v1/flags/")
        XCTAssertTrue(request.allHTTPHeaderFields?.contains(where: { $0.key == "X-Environment-Key" }) ?? false)
        XCTAssertNil(request.httpBody)
    }
    
    func testGetIdentityRequest() throws {
        let url = try XCTUnwrap(baseUrl)
        let route = Router.getIdentity(identity: "6056BCBF")
        let request = try route.request(baseUrl: url, apiKey: apiKey)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString, "https://edge.api.flagsmith.com/api/v1/identities/?identifier=6056BCBF")
        XCTAssertTrue(request.allHTTPHeaderFields?.contains(where: { $0.key == "X-Environment-Key" }) ?? false)
        XCTAssertNil(request.httpBody)
    }
    
    func testPostTraitRequest() throws {
        let trait = Trait(key: "meaning_of_life", value: 42)
        let url = try XCTUnwrap(baseUrl)
        let route = Router.postTrait(trait: trait, identity: "CFF8D9CA")
        let request = try route.request(baseUrl: url, apiKey: apiKey, using: encoder)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://edge.api.flagsmith.com/api/v1/traits/")
        
        let json = try """
        {
          "identity" : {
            "identifier" : "CFF8D9CA"
          },
          "trait_key" : "meaning_of_life",
          "trait_value" : 42
        }
        """.json(using: .utf8)
        let body = try request.httpBody.json()
        
        XCTAssertEqual(body, json)
    }

    func testPostTraitsRequest() throws {
        let questionTrait = Trait(key: "question_meaning_of_life", value: "6 x 9")
        let meaningTrait = Trait(key: "meaning_of_life", value: 42)
        let url = try XCTUnwrap(baseUrl)
        let route = Router.postTraits(identity: "A1B2C3D4", traits: [questionTrait, meaningTrait])
        let request = try route.request(baseUrl: url, apiKey: apiKey, using: encoder)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://edge.api.flagsmith.com/api/v1/identities/?identifier=A1B2C3D4")

        let expectedJson = try """
        {
          "traits" : [
            {
              "trait_key" : "question_meaning_of_life",
              "trait_value" : "6 x 9"
            },
            {
              "trait_key" : "meaning_of_life",
              "trait_value" : 42
            }
          ],
          "identifier" : "A1B2C3D4"
        }
        """.json(using: .utf8)
        let body = try request.httpBody.json()
        XCTAssertEqual(body, expectedJson)
    }
    
    func testPostAnalyticsRequest() throws {
        let events: [String: Int] = [
            "one": 1,
            "two": 2
        ]
        
        let url = try XCTUnwrap(baseUrl)
        let route = Router.postAnalytics(events: events)
        let request = try route.request(baseUrl: url, apiKey: apiKey, using: encoder)
        
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://edge.api.flagsmith.com/api/v1/analytics/flags/")
        
        let json = try """
        {
          "one" : 1,
          "two" : 2
        }
        """.json(using: .utf8)
        XCTAssertEqual(try request.httpBody.json(), json)
    }
}
