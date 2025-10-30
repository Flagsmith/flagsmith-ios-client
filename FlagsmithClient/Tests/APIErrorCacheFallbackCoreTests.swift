//
//  APIErrorCacheFallbackCoreTests.swift
//  FlagsmithClientTests
//
//  Core API error scenarios with cache fallback behavior
//  Customer requirement: "When fetching flags and we run into an error and have a valid cache we should return the cached flags"
//

@testable import FlagsmithClient
import XCTest

final class APIErrorCacheFallbackCoreTests: FlagsmithClientTestCase {
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
    
    // MARK: - Core API Error Cache Fallback Tests
    
    func testGetFeatureFlags_APIFailure_ReturnsCachedFlags() throws {
        // This test works with mock data, no real API key needed
        let expectation = expectation(description: "API failure with cache fallback")
        
        // Create mock flags for cache
        let cachedFlags = [
            Flag(featureName: "cached_feature_1", value: .string("cached_value_1"), enabled: true, featureType: "FLAG"),
            Flag(featureName: "cached_feature_2", value: .string("cached_value_2"), enabled: false, featureType: "FLAG")
        ]
        
        // Pre-populate cache with successful response
        var mockRequest = URLRequest(url: TestConfig.baseURL.appendingPathComponent("flags/"))
        mockRequest.setValue(TestConfig.apiKey, forHTTPHeaderField: "X-Environment-Key")
        let cachedResponse = try createMockCachedResponse(for: mockRequest, with: cachedFlags)
        testCache.storeCachedResponse(cachedResponse, for: mockRequest)
        
        // Mock API failure by using invalid API key
        Flagsmith.shared.apiKey = "invalid-api-key"
        
        // Request should fail API call but return cached flags
        Flagsmith.shared.getFeatureFlags { result in
            switch result {
            case .success(let flags):
                // Should return cached flags
                XCTAssertEqual(flags.count, 2, "Should return cached flags")
                XCTAssertEqual(flags.first?.feature.name, "cached_feature_1", "Should return first cached flag")
                XCTAssertEqual(flags.last?.feature.name, "cached_feature_2", "Should return second cached flag")
            case .failure(let error):
                XCTFail("Should return cached flags instead of failing: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testGetFeatureFlags_APIFailure_NoCache_ReturnsDefaultFlags() throws {
        // This test works with mock data, no real API key needed
        let expectation = expectation(description: "API failure with no cache, default flags fallback")
        
        // Set up default flags
        let defaultFlags = [
            Flag(featureName: "default_feature", value: .string("default_value"), enabled: true, featureType: "FLAG")
        ]
        Flagsmith.shared.defaultFlags = defaultFlags
        
        // Ensure no cache exists
        testCache.removeAllCachedResponses()
        
        // Mock API failure
        Flagsmith.shared.apiKey = "invalid-api-key"
        
        // Request should fail API call and return default flags
        Flagsmith.shared.getFeatureFlags { result in
            switch result {
            case .success(let flags):
                // Should return default flags
                XCTAssertEqual(flags.count, 1, "Should return default flags")
                XCTAssertEqual(flags.first?.feature.name, "default_feature", "Should return default flag")
            case .failure(let error):
                XCTFail("Should return default flags instead of failing: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testGetFeatureFlags_APIFailure_NoCacheNoDefaults_ReturnsError() throws {
        // This test works with mock data, no real API key needed
        let expectation = expectation(description: "API failure with no cache and no defaults")
        
        // Ensure no cache and no defaults
        testCache.removeAllCachedResponses()
        Flagsmith.shared.defaultFlags = []
        
        // Mock API failure
        Flagsmith.shared.apiKey = "invalid-api-key"
        
        // Request should fail
        Flagsmith.shared.getFeatureFlags { result in
            switch result {
            case .success(_):
                XCTFail("Should fail when no cache and no defaults")
            case .failure(let error):
                // Should return the original API error
                XCTAssertTrue(error is FlagsmithError, "Should return FlagsmithError")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
