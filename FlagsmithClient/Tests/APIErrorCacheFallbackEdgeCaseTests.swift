//
//  APIErrorCacheFallbackEdgeCaseTests.swift
//  FlagsmithClientTests
//
//  Edge case API error scenarios with cache fallback behavior
//

@testable import FlagsmithClient
import XCTest

final class APIErrorCacheFallbackEdgeCaseTests: FlagsmithClientTestCase {
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
    
    // MARK: - Edge Case Tests
    
    func testCacheFallback_CorruptedCache_ReturnsDefaultFlags() throws {
        // This test works with mock data, no real API key needed
        let expectation = expectation(description: "Corrupted cache with default flags fallback")
        
        // Create corrupted cache entry
        let corruptedData = "invalid json data".data(using: .utf8)!
        var mockRequest = URLRequest(url: TestConfig.baseURL.appendingPathComponent("flags/"))
        mockRequest.setValue(TestConfig.apiKey, forHTTPHeaderField: "X-Environment-Key")
        
        let httpResponse = HTTPURLResponse(
            url: mockRequest.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/json",
                "Cache-Control": "max-age=300"
            ]
        )!
        
        let corruptedCachedResponse = CachedURLResponse(response: httpResponse, data: corruptedData)
        testCache.storeCachedResponse(corruptedCachedResponse, for: mockRequest)
        
        // Set up default flags
        let defaultFlags = [
            Flag(featureName: "default_feature", value: .string("default_value"), enabled: true, featureType: "FLAG")
        ]
        Flagsmith.shared.defaultFlags = defaultFlags
        
        // Mock API failure
        Flagsmith.shared.apiKey = "invalid-api-key"
        
        // Request should fail API call and return default flags (not corrupted cache)
        Flagsmith.shared.getFeatureFlags { result in
            switch result {
            case .success(let flags):
                // Should return default flags, not corrupted cache
                XCTAssertEqual(flags.count, 1, "Should return default flags")
                XCTAssertEqual(flags.first?.feature.name, "default_feature", "Should return default flag, not corrupted cache")
            case .failure(let error):
                XCTFail("Should return default flags instead of failing: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
