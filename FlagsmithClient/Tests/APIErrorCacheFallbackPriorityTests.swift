//
//  APIErrorCacheFallbackPriorityTests.swift
//  FlagsmithClientTests
//
//  Cache priority API error scenarios with cache fallback behavior
//

@testable import FlagsmithClient
import XCTest

final class APIErrorCacheFallbackPriorityTests: FlagsmithClientTestCase {
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
    
    private func createMockCachedResponse(for request: URLRequest, with flags: [Flag]) throws -> CachedURLResponse {
        let jsonData = try JSONEncoder().encode(flags)
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
    
    // MARK: - Cache Priority Tests (cache > defaults > error)
    
    func testCacheFallback_Priority_CacheOverDefaults() throws {
        // This test works with mock data, no real API key needed
        let expectation = expectation(description: "Cache priority over defaults")
        
        // Set up both cache and defaults
        let cachedFlags = [
            Flag(featureName: "cached_feature", value: .string("cached_value"), enabled: true, featureType: "FLAG")
        ]
        let defaultFlags = [
            Flag(featureName: "default_feature", value: .string("default_value"), enabled: true, featureType: "FLAG")
        ]
        
        // Pre-populate cache
        var mockRequest = URLRequest(url: TestConfig.baseURL.appendingPathComponent("flags/"))
        mockRequest.setValue(TestConfig.apiKey, forHTTPHeaderField: "X-Environment-Key")
        let cachedResponse = try createMockCachedResponse(for: mockRequest, with: cachedFlags)
        testCache.storeCachedResponse(cachedResponse, for: mockRequest)
        
        // Set up defaults
        Flagsmith.shared.defaultFlags = defaultFlags
        
        // Mock API failure
        Flagsmith.shared.apiKey = "invalid-api-key"
        
        // Request should return cached flags, not default flags
        Flagsmith.shared.getFeatureFlags { result in
            switch result {
            case .success(let flags):
                // Should return cached flags, not defaults
                XCTAssertEqual(flags.count, 1, "Should return cached flags")
                XCTAssertEqual(flags.first?.feature.name, "cached_feature", "Should return cached flag, not default")
            case .failure(let error):
                XCTFail("Should return cached flags instead of failing: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
