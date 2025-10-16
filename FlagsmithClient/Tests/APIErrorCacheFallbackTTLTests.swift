//
//  APIErrorCacheFallbackTTLTests.swift
//  FlagsmithClientTests
//
//  Cache TTL and expiration API error scenarios with cache fallback behavior
//

@testable import FlagsmithClient
import XCTest

final class APIErrorCacheFallbackTTLTests: FlagsmithClientTestCase {
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
    
    // MARK: - Cache TTL and Expiration Tests
    
    func testCacheFallback_ExpiredCache_ReturnsDefaultFlags() throws {
        // This test works with mock data, no real API key needed
        let expectation = expectation(description: "Expired cache with default flags fallback")
        
        // Create expired cache entry (simulate by using old timestamp)
        let cachedFlags = [
            Flag(featureName: "expired_feature", value: .string("expired_value"), enabled: true, featureType: "FLAG")
        ]
        
        var mockRequest = URLRequest(url: TestConfig.baseURL.appendingPathComponent("flags/"))
        mockRequest.setValue(TestConfig.apiKey, forHTTPHeaderField: "X-Environment-Key")
        
        // Create expired response (simulate by setting old date)
        let expiredDate = Date().addingTimeInterval(-400) // 400 seconds ago (beyond 300s TTL)
        let httpResponse = HTTPURLResponse(
            url: mockRequest.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/json",
                "Cache-Control": "max-age=300",
                "Date": "Mon, 01 Jan 2024 00:00:00 GMT"
            ]
        )!
        
        let jsonData = try JSONEncoder().encode(cachedFlags)
        let expiredCachedResponse = CachedURLResponse(response: httpResponse, data: jsonData)
        testCache.storeCachedResponse(expiredCachedResponse, for: mockRequest)
        
        // Set up default flags
        let defaultFlags = [
            Flag(featureName: "default_feature", value: .string("default_value"), enabled: true, featureType: "FLAG")
        ]
        Flagsmith.shared.defaultFlags = defaultFlags
        
        // Mock API failure
        Flagsmith.shared.apiKey = "invalid-api-key"
        
        // Request should fail API call and return default flags (not expired cache)
        Flagsmith.shared.getFeatureFlags { result in
            switch result {
            case .success(let flags):
                // Should return default flags, not expired cache
                XCTAssertEqual(flags.count, 1, "Should return default flags")
                XCTAssertEqual(flags.first?.feature.name, "default_feature", "Should return default flag, not expired cache")
            case .failure(let error):
                XCTFail("Should return default flags instead of failing: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
