//
//  CustomHeadersTests.swift
//  FlagsmithClientTests
//

@testable import FlagsmithClient
import XCTest

final class CustomHeadersTests: FlagsmithClientTestCase {
    override func tearDown() {
        super.tearDown()
        Flagsmith.shared.customHeaders = nil
    }

    /// Verify the `customHeaders` closure is invoked when a request is made.
    func testCustomHeadersClosureIsInvoked() throws {
        let closureInvoked = expectation(description: "customHeaders closure invoked")

        Flagsmith.shared.customHeaders = {
            closureInvoked.fulfill()
            return ["X-Test-Header": "value"]
        }
        Flagsmith.shared.apiKey = "mock-test-api-key"
        // Force a quick failure so the request doesn't hang
        Flagsmith.shared.baseURL = URL(fileURLWithPath: "/dev/null")

        Flagsmith.shared.getFeatureFlags { _ in }

        wait(for: [closureInvoked], timeout: 1.0)
    }

    /// Verify that when `customHeaders` is nil, requests still work normally.
    func testNilCustomHeadersDoesNotCrash() throws {
        Flagsmith.shared.customHeaders = nil
        Flagsmith.shared.apiKey = "mock-test-api-key"
        Flagsmith.shared.baseURL = URL(fileURLWithPath: "/dev/null")

        let requestFinished = expectation(description: "Request finished without crash")

        Flagsmith.shared.getFeatureFlags { _ in
            requestFinished.fulfill()
        }

        wait(for: [requestFinished], timeout: 1.0)
    }

    /// Verify the closure is invoked on every request (not cached).
    func testCustomHeadersClosureInvokedEveryRequest() throws {
        var invocationCount = 0
        Flagsmith.shared.customHeaders = {
            invocationCount += 1
            return [:]
        }
        Flagsmith.shared.apiKey = "mock-test-api-key"
        Flagsmith.shared.baseURL = URL(fileURLWithPath: "/dev/null")

        let firstRequest = expectation(description: "First request")
        let secondRequest = expectation(description: "Second request")

        Flagsmith.shared.getFeatureFlags { _ in firstRequest.fulfill() }
        Flagsmith.shared.getFeatureFlags { _ in secondRequest.fulfill() }

        wait(for: [firstRequest, secondRequest], timeout: 2.0)
        XCTAssertEqual(invocationCount, 2, "customHeaders should be invoked for every request")
    }
}
