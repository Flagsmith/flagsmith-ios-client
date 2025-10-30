//
//  APIErrorCacheFallbackIdentityTests.swift
//  FlagsmithClientTests
//
//  Identity-specific API error scenarios with cache fallback behavior
//

@testable import FlagsmithClient
import XCTest

final class APIErrorCacheFallbackIdentityTests: FlagsmithClientTestCase {
    var testCache: URLCache!
    
    override func setUp() {
        super.setUp()
        
        // Create isolated cache for testing
        testCache = URLCache(memoryCapacity: 8 * 1024 * 1024, diskCapacity: 64 * 1024 * 1024, directory: nil)
        
        // Reset Flagsmith to known state using TestConfig
        Flagsmith.shared.apiKey = TestConfig.hasRealApiKey ? TestConfig.apiKey : "mock-test-api-key"
        Flagsmith.shared.baseURL = TestConfig.baseURL
        Flagsmith.shared.enableRealtimeUpdates = false
        Flagsmith.shared.cacheConfig.useCache = true
        Flagsmith.shared.cacheConfig.skipAPI = false
        Flagsmith.shared.cacheConfig.cache = testCache
        Flagsmith.shared.cacheConfig.cacheTTL = 300
        Flagsmith.shared.defaultFlags = []
    }
    
    override func tearDown() {
        testCache.removeAllCachedResponses()
        Flagsmith.shared.cacheConfig.useCache = false
        Flagsmith.shared.cacheConfig.skipAPI = false
        Flagsmith.shared.apiKey = nil
        super.tearDown()
    }
    
    // MARK: - Test Helper Methods
    
    private func extractStringValue(from typedValue: TypedValue?) -> String? {
        guard let typedValue = typedValue else { return nil }
        switch typedValue {
        case .string(let value):
            return value
        case .int(let value):
            return String(value)
        case .bool(let value):
            return String(value)
        case .float(let value):
            return String(value)
        case .null:
            return nil
        }
    }
    
    private func createMockIdentityCachedResponse(for request: URLRequest, with identity: Identity) throws -> CachedURLResponse {
        // Create JSON manually since Identity doesn't conform to Encodable
        let jsonString = """
        {
            "identifier": "test-user-123",
            "traits": [],
            "flags": [
                {
                    "id": 1,
                    "feature": {
                        "id": 1,
                        "name": "\(identity.flags.first?.feature.name ?? "test_feature")",
                        "type": "FLAG"
                    },
                    "enabled": \(identity.flags.first?.enabled ?? true),
                    "feature_state_value": "\(extractStringValue(from: identity.flags.first?.value) ?? "test_value")"
                }
            ]
        }
        """
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create JSON data"])
        }
        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/json",
                "Cache-Control": "max-age=300"
            ]
        )!
        return CachedURLResponse(response: httpResponse, data: jsonData)
    }
    
    // MARK: - Identity-Specific Cache Fallback Tests
    
    func testGetFeatureFlagsForIdentity_APIFailure_ReturnsCachedFlags() throws {
        // Skip if no real API key since this test needs to make real network calls
        guard TestConfig.hasRealApiKey else {
            throw XCTSkip("Requires real API key for identity testing")
        }
        
        let expectation = expectation(description: "API failure with identity, cache fallback")
        
        let testIdentity = TestConfig.testIdentity
        let cachedFlags = [
            Flag(featureName: "user_feature", value: .string("user_value"), enabled: true, featureType: "FLAG")
        ]
        let cachedIdentity = Identity(flags: cachedFlags, traits: [], transient: false)
        
        // Pre-populate cache with successful identity response
        let identityURL = TestConfig.baseURL.appendingPathComponent("identities/")
        var components = URLComponents(url: identityURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "identifier", value: testIdentity)]
        var mockRequest = URLRequest(url: components.url!)
        mockRequest.setValue(TestConfig.apiKey, forHTTPHeaderField: "X-Environment-Key")
        let cachedResponse = try createMockIdentityCachedResponse(for: mockRequest, with: cachedIdentity)
        testCache.storeCachedResponse(cachedResponse, for: mockRequest)
        
        // Mock API failure
        Flagsmith.shared.apiKey = "invalid-api-key"
        
        // Request should fail API call but return cached flags
        Flagsmith.shared.getFeatureFlags(forIdentity: testIdentity) { result in
            switch result {
            case .success(let flags):
                // Should return cached flags
                XCTAssertEqual(flags.count, 1, "Should return cached flags")
                XCTAssertEqual(flags.first?.feature.name, "user_feature", "Should return cached user flag")
            case .failure(let error):
                XCTFail("Should return cached flags instead of failing: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
