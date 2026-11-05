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
        // x-release-please-start-version
        XCTAssertEqual(request.allHTTPHeaderFields?["User-Agent"], "flagsmith-swift-ios-sdk/3.10.1")
        // x-release-please-end
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

    func testPostEventsRequest() throws {
        // Given
        let url = try XCTUnwrap(URL(string: "https://events.api.flagsmith.com/"))
        let event = Event(event: "checkout_completed", featureName: nil, identifier: "user_123", value: "42",
                          traits: nil, metadata: ["currency": .string("GBP")], timestamp: 1_700_000_000_000)

        // When
        let request = try Router.postEvents(events: [event]).request(baseUrl: url, apiKey: apiKey, using: encoder)

        // Then
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://events.api.flagsmith.com/v1/events")
        XCTAssertEqual(request.allHTTPHeaderFields?["X-Environment-Key"], apiKey)
        let json = try """
        {
          "events" : [
            {
              "event" : "checkout_completed",
              "feature_name" : null,
              "identifier" : "user_123",
              "value" : "42",
              "traits" : null,
              "metadata" : { "currency" : "GBP" },
              "timestamp" : 1700000000000
            }
          ]
        }
        """.json(using: .utf8)
        XCTAssertEqual(try request.httpBody.json(), json)
    }
}
