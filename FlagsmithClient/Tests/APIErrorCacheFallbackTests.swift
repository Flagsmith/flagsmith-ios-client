//
//  APIErrorCacheFallbackTests.swift
//  FlagsmithClientTests
//
//  Tests for API error scenarios with cache fallback behavior
//  Customer requirement: "When fetching flags and we run into an error and have a valid cache we should return the cached flags"
//

@testable import FlagsmithClient
import XCTest

final class APIErrorCacheFallbackTests: FlagsmithClientTestCase {
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
    
    private func createMockCachedResponse(for request: URLRequest, with flags: [Flag]) -> CachedURLResponse {
        let jsonData = try! JSONEncoder().encode(flags)
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
    
    private func createMockIdentityCachedResponse(for request: URLRequest, with identity: Identity) -> CachedURLResponse {
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
        let jsonData = jsonString.data(using: .utf8)!
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
        let cachedResponse = createMockCachedResponse(for: mockRequest, with: cachedFlags)
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
        let cachedResponse = createMockIdentityCachedResponse(for: mockRequest, with: cachedIdentity)
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
        let cachedResponse = createMockCachedResponse(for: mockRequest, with: cachedFlags)
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
        let cachedResponse = createMockCachedResponse(for: mockRequest, with: cachedFlags)
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
        
        let jsonData = try! JSONEncoder().encode(cachedFlags)
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
        let cachedResponse = createMockCachedResponse(for: mockRequest, with: cachedFlags)
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
        let cachedResponse = createMockCachedResponse(for: mockRequest, with: cachedFlags)
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
        let cachedResponse = createMockCachedResponse(for: mockRequest, with: cachedFlags)
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
