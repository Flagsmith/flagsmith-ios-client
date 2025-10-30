//
//  APIErrorCacheFallbackFeatureTests.swift
//  FlagsmithClientTests
//
//  Feature-specific method API error scenarios with cache fallback behavior
//

@testable import FlagsmithClient
import XCTest

final class APIErrorCacheFallbackFeatureTests: FlagsmithClientTestCase {
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
    
    // MARK: - Feature-Specific Method Cache Fallback Tests
    
    func testHasFeatureFlag_APIFailure_ReturnsCachedResult() throws {
        // This test works with mock data, no real API key needed
        let expectation = expectation(description: "hasFeatureFlag API failure with cache fallback")
        
        let testFeature = "test_feature"
        let cachedFlags = [
            Flag(featureName: testFeature, value: .string("test_value"), enabled: true, featureType: "FLAG")
        ]
        
        // Pre-populate cache
        var mockRequest = URLRequest(url: TestConfig.baseURL.appendingPathComponent("flags/"))
        mockRequest.setValue(TestConfig.apiKey, forHTTPHeaderField: "X-Environment-Key")
        let cachedResponse = try createMockCachedResponse(for: mockRequest, with: cachedFlags)
        testCache.storeCachedResponse(cachedResponse, for: mockRequest)
        
        // Mock API failure
        Flagsmith.shared.apiKey = "invalid-api-key"
        
        // Request should fail API call but return cached result
        Flagsmith.shared.hasFeatureFlag(withID: testFeature) { result in
            switch result {
            case .success(let hasFlag):
                // Should return cached result
                XCTAssertTrue(hasFlag, "Should return cached enabled state")
            case .failure(let error):
                XCTFail("Should return cached result instead of failing: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testGetValueForFeature_APIFailure_ReturnsCachedValue() throws {
        // This test works with mock data, no real API key needed
        let expectation = expectation(description: "getValueForFeature API failure with cache fallback")
        
        let testFeature = "test_feature"
        let testValue = "cached_value"
        let cachedFlags = [
            Flag(featureName: testFeature, value: .string(testValue), enabled: true, featureType: "FLAG")
        ]
        
        // Pre-populate cache
        var mockRequest = URLRequest(url: TestConfig.baseURL.appendingPathComponent("flags/"))
        mockRequest.setValue(TestConfig.apiKey, forHTTPHeaderField: "X-Environment-Key")
        let cachedResponse = try createMockCachedResponse(for: mockRequest, with: cachedFlags)
        testCache.storeCachedResponse(cachedResponse, for: mockRequest)
        
        // Mock API failure
        Flagsmith.shared.apiKey = "invalid-api-key"
        
        // Request should fail API call but return cached value
        Flagsmith.shared.getValueForFeature(withID: testFeature) { result in
            switch result {
            case .success(let value):
                // Should return cached value
                XCTAssertNotNil(value, "Should return cached value")
                if case .string(let stringValue) = value {
                    XCTAssertEqual(stringValue, testValue, "Should return cached string value")
                } else {
                    XCTFail("Expected string value")
                }
            case .failure(let error):
                XCTFail("Should return cached value instead of failing: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
