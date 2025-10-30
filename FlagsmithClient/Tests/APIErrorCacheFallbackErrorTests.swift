//
//  APIErrorCacheFallbackErrorTests.swift
//  FlagsmithClientTests
//
//  Different error type API error scenarios with cache fallback behavior
//

@testable import FlagsmithClient
import XCTest

final class APIErrorCacheFallbackErrorTests: FlagsmithClientTestCase {
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
    
    // MARK: - Different Error Type Tests
    
    func testCacheFallback_NetworkError_ReturnsCachedFlags() throws {
        // This test works with mock data, no real API key needed
        let expectation = expectation(description: "Network error with cache fallback")
        
        // Create cached flags
        let cachedFlags = [
            Flag(featureName: "network_cached_feature", value: .string("network_cached_value"), enabled: true, featureType: "FLAG")
        ]
        
        // Pre-populate cache
        var mockRequest = URLRequest(url: TestConfig.baseURL.appendingPathComponent("flags/"))
        mockRequest.setValue(TestConfig.apiKey, forHTTPHeaderField: "X-Environment-Key")
        let cachedResponse = try createMockCachedResponse(for: mockRequest, with: cachedFlags)
        testCache.storeCachedResponse(cachedResponse, for: mockRequest)
        
        // Simulate network error by using invalid API key (this will cause API failure)
        Flagsmith.shared.apiKey = "invalid-api-key"
        
        // Request should fail API call but return cached flags
        Flagsmith.shared.getFeatureFlags { result in
            switch result {
            case .success(let flags):
                // Should return cached flags
                XCTAssertEqual(flags.count, 1, "Should return cached flags")
                XCTAssertEqual(flags.first?.feature.name, "network_cached_feature", "Should return cached flag")
            case .failure(let error):
                XCTFail("Should return cached flags instead of failing: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testCacheFallback_ServerError_ReturnsCachedFlags() throws {
        // This test works with mock data, no real API key needed
        let expectation = expectation(description: "Server error with cache fallback")
        
        // Create cached flags
        let cachedFlags = [
            Flag(featureName: "server_cached_feature", value: .string("server_cached_value"), enabled: true, featureType: "FLAG")
        ]
        
        // Pre-populate cache
        var mockRequest = URLRequest(url: TestConfig.baseURL.appendingPathComponent("flags/"))
        mockRequest.setValue(TestConfig.apiKey, forHTTPHeaderField: "X-Environment-Key")
        let cachedResponse = try createMockCachedResponse(for: mockRequest, with: cachedFlags)
        testCache.storeCachedResponse(cachedResponse, for: mockRequest)
        
        // Simulate server error by using invalid API key (this will cause API failure)
        Flagsmith.shared.apiKey = "invalid-api-key"
        
        // Request should fail API call but return cached flags
        Flagsmith.shared.getFeatureFlags { result in
            switch result {
            case .success(let flags):
                // Should return cached flags
                XCTAssertEqual(flags.count, 1, "Should return cached flags")
                XCTAssertEqual(flags.first?.feature.name, "server_cached_feature", "Should return cached flag")
            case .failure(let error):
                XCTFail("Should return cached flags instead of failing: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
