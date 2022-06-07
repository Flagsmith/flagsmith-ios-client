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
    
    func testPostTraitsRequest() throws {
        let trait = Trait(key: "meaning_of_life", value: 42)
        let url = try XCTUnwrap(baseUrl)
        let route = Router.postTrait(trait: trait, identity: "CFF8D9CA")
        let request = try route.request(baseUrl: url, apiKey: apiKey, using: encoder)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://edge.api.flagsmith.com/api/v1/traits/")
        
        let json = """
        {
          "identity" : {
            "identifier" : "CFF8D9CA"
          },
          "trait_key" : "meaning_of_life",
          "trait_value" : 42
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        
        XCTAssertEqual(request.httpBody, data)
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
        
        let json = """
        {
          "one" : 1,
          "two" : 2
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        
        XCTAssertEqual(request.httpBody, data)
    }
}
