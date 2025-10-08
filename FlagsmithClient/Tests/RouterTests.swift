//
//  RouterTests.swift
//  FlagsmithClientTests
//
//  Created by Richard Piazza on 3/21/22.
//

@testable import FlagsmithClient
import XCTest

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
    
    func testUserAgentHeader() throws {
        let url = try XCTUnwrap(baseUrl)
        let route = Router.getFlags
        let request = try route.request(baseUrl: url, apiKey: apiKey)
        
        // Verify User-Agent header is present
        XCTAssertTrue(request.allHTTPHeaderFields?.contains(where: { $0.key == "User-Agent" }) ?? false)
        
        // Verify User-Agent header format
        let userAgent = request.allHTTPHeaderFields?["User-Agent"]
        XCTAssertNotNil(userAgent)
        XCTAssertTrue(userAgent?.hasPrefix("flagsmith-swift-ios-sdk/") ?? false)
        
        // Verify the format is correct (should end with a semantic version number)
        let expectedPattern = "^flagsmith-swift-ios-sdk/[0-9]+\\.[0-9]+\\.[0-9]+$"
        let regex = try NSRegularExpression(pattern: expectedPattern)
        let range = NSRange(location: 0, length: userAgent?.count ?? 0)
        XCTAssertTrue(regex.firstMatch(in: userAgent ?? "", options: [], range: range) != nil, 
                     "User-Agent should match pattern 'flagsmith-swift-ios-sdk/<version>', got: \(userAgent ?? "nil")")
    }
    
    func testUserAgentHeaderFormat() {
        // Test that the User-Agent format is correct
        let userAgent = Flagsmith.userAgent
        XCTAssertTrue(userAgent.hasPrefix("flagsmith-swift-ios-sdk/"))
        
        // Should have a semantic version number (e.g., 3.8.4)
        let versionPart = String(userAgent.dropFirst("flagsmith-swift-ios-sdk/".count))
        XCTAssertTrue(versionPart.range(of: #"^\d+\.\d+\.\d+$"#, options: NSString.CompareOptions.regularExpression) != nil,
                     "Version part should be a semantic version number (e.g., 3.8.4), got: \(versionPart)")
        
        // Should be the expected SDK version
        XCTAssertEqual(versionPart, "3.8.4", "Expected SDK version 3.8.4, got: \(versionPart)")
    }

    func testGetIdentityRequest() throws {
        let url = try XCTUnwrap(baseUrl)
        let route = Router.getIdentity(identity: "6056BCBF")
        let request = try route.request(baseUrl: url, apiKey: apiKey)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString,
                       "https://edge.api.flagsmith.com/api/v1/identities/?identifier=6056BCBF")
        XCTAssertTrue(request.allHTTPHeaderFields?.contains(where: { $0.key == "X-Environment-Key" }) ?? false)
        XCTAssertNil(request.httpBody)
    }

    func testGetIdentityRequest_Transient() throws {
        let url = try XCTUnwrap(baseUrl)
        let route = Router.getIdentity(identity: "6056BCBF", transient: true)
        let request = try route.request(baseUrl: url, apiKey: apiKey)
        XCTAssertEqual(request.url?.absoluteString,
                       "https://edge.api.flagsmith.com/api/v1/identities/?identifier=6056BCBF&transient=true")
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
        let meaningTrait = Trait(key: "meaning_of_life", value: 42, transient: true)
        let url = try XCTUnwrap(baseUrl)
        let route = Router.postTraits(identity: "A1B2C3D4", traits: [questionTrait, meaningTrait])
        let request = try route.request(baseUrl: url, apiKey: apiKey, using: encoder)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://edge.api.flagsmith.com/api/v1/identities/")

        let expectedJson = try """
        {
          "traits" : [
            {
              "trait_key" : "question_meaning_of_life",
              "trait_value" : "6 x 9",
              "transient": false
            },
            {
              "trait_key" : "meaning_of_life",
              "trait_value" : 42,
              "transient": true
            }
          ],
          "identifier" : "A1B2C3D4",
          "transient": false
        }
        """.json(using: .utf8)
        let body = try request.httpBody.json()
        XCTAssertEqual(body, expectedJson)
    }

    func testPostTraitsRequest_TransientIdentity() throws {
        let url = try XCTUnwrap(baseUrl)
        let route = Router.postTraits(identity: "A1B2C3D4", traits: [], transient: true)
        let request = try route.request(baseUrl: url, apiKey: apiKey, using: encoder)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://edge.api.flagsmith.com/api/v1/identities/")

        let expectedJson = try """
        {
          "traits" : [],
          "identifier" : "A1B2C3D4",
          "transient": true
        }
        """.json(using: .utf8)
        let body = try request.httpBody.json()
        XCTAssertEqual(body, expectedJson)
    }

    func testPostAnalyticsRequest() throws {
        let events: [String: Int] = [
            "one": 1,
            "two": 2,
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
