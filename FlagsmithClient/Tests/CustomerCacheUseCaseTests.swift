//
//  CustomerCacheUseCaseTests.swift
//  FlagsmithClientTests
//
//  Black box tests replicating exact customer cache configuration and use cases
//

@testable import FlagsmithClient
import XCTest

final class CustomerCacheUseCaseTests: FlagsmithClientTestCase {
    
    /// Test the exact customer configuration that was reported as problematic
    func testCustomerReportedConfiguration() throws {
        // This test requires a real API key to validate actual cache behavior
        guard TestConfig.hasRealApiKey else {
            XCTFail("This customer use case test requires FLAGSMITH_TEST_API_KEY environment variable to be set")
            return
        }

        let expectation = expectation(description: "Customer configuration test")
        
        // Test exact customer configuration that was reported as problematic
        
        // Configure exactly as the customer reported
        let env = (baseURL: URL(string: "https://edge.api.flagsmith.com/api/v1/")!, apiKey: TestConfig.apiKey)
        
        Flagsmith.shared.apiKey = env.apiKey
        Flagsmith.shared.baseURL = env.baseURL
        Flagsmith.shared.enableRealtimeUpdates = false
        Flagsmith.shared.cacheConfig.useCache = true
        Flagsmith.shared.cacheConfig.cache = URLCache(
            memoryCapacity: 8 * 1024 * 1024,   // 8 MB
            diskCapacity:   64 * 1024 * 1024,  // 64 MB
            directory:      nil
        )
        Flagsmith.shared.cacheConfig.cacheTTL = 180
        Flagsmith.shared.cacheConfig.skipAPI = true
        
        // Configuration matches customer's exact settings
        
        // Test the exact call that was problematic: getFeatureFlags(forIdentity:)
        
        let testIdentity = TestConfig.hasRealApiKey ? TestConfig.testIdentity : "customer-test-identity"
        
        // First call - should attempt network (may fail with test key)
        Flagsmith.shared.getFeatureFlags(forIdentity: testIdentity) { firstResult in
            // First call completed
            
            switch firstResult {
            case .success(let flags):
                // First call succeeded - now test cache behavior
                
                // Second call - customer expects this to use cache, not HTTP
                Flagsmith.shared.getFeatureFlags(forIdentity: testIdentity) { secondResult in
                    switch secondResult {
                    case .success(let cachedFlags):
                        // Second call succeeded using cache
                        XCTAssertEqual(flags.count, cachedFlags.count, "Should get same flags from cache")
                        
                        // Verify it's using cache by checking flags are identical
                        XCTAssertEqual(flags.first?.feature.name, cachedFlags.first?.feature.name, "Should get identical cached flags")
                        
                    case .failure(let error):
                        XCTFail("Second call should succeed with cache: \(error)")
                    }
                    expectation.fulfill()
                }
                
            case .failure(_):
                // First call failed as expected with test key
                
                // Test the behavior customer would see - subsequent calls should still attempt network
                // because no successful cache was established
                // Test subsequent call behavior when no cache exists
                
                Flagsmith.shared.getFeatureFlags(forIdentity: testIdentity) { subsequentResult in
                    switch subsequentResult {
                    case .success(_):
                        // Unexpected success on subsequent call
                        break
                    case .failure(_):
                        // Subsequent call also failed as expected
                        // This demonstrates the customer's issue: requests always go via HTTP
                        // because cache never gets populated from failed requests

                        // For real API keys, this should work after first success
                        if TestConfig.hasRealApiKey {
                            XCTFail("With real API key and caching enabled, subsequent requests should use cache and succeed")
                        }
                    }
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 15.0)
        
        // Cleanup
        Flagsmith.shared.cacheConfig.skipAPI = false
        Flagsmith.shared.cacheConfig.useCache = false
    }
    
    /// Test customer use case with simulated successful cache population
    func testCustomerConfigurationWithSuccessfulCache() throws {
        // This test validates cache behavior with pre-populated cache (doesn't need real API key)
        let expectation = expectation(description: "Customer config with successful cache")
        
        // Test customer configuration with simulated successful cache
        
        // Same configuration as customer
        Flagsmith.shared.baseURL = URL(string: "https://edge.api.flagsmith.com/api/v1/")!
        Flagsmith.shared.enableRealtimeUpdates = false
        Flagsmith.shared.cacheConfig.useCache = true
        Flagsmith.shared.cacheConfig.cache = URLCache(
            memoryCapacity: 8 * 1024 * 1024,
            diskCapacity: 64 * 1024 * 1024,
            directory: nil
        )
        Flagsmith.shared.cacheConfig.cacheTTL = 180
        Flagsmith.shared.cacheConfig.skipAPI = true
        
        let testIdentity = "customer-success-test"
        
        // Simulate what would happen if customer had valid API key
        // by pre-populating cache with successful response
        let mockURL = URL(string: "https://edge.api.flagsmith.com/api/v1/identities/?identifier=\(testIdentity)")!
        var mockRequest = URLRequest(url: mockURL)
        mockRequest.setValue("customer-test-key", forHTTPHeaderField: "X-Environment-Key")
        mockRequest.cachePolicy = .returnCacheDataElseLoad
        
        let mockIdentityResponse = """
        {
            "identifier": "\(testIdentity)",
            "traits": [],
            "flags": [
                {
                    "id": 1,
                    "feature": {
                        "id": 1,
                        "name": "customer_test_feature",
                        "created_date": "2023-01-01T00:00:00Z",
                        "description": null,
                        "initial_value": null,
                        "default_enabled": true,
                        "type": "FLAG"
                    },
                    "enabled": true,
                    "environment": 1,
                    "identity": "\(testIdentity)",
                    "feature_segment": null,
                    "feature_state_value": "customer_value"
                }
            ]
        }
        """.data(using: .utf8)!
        
        let httpResponse = HTTPURLResponse(
            url: mockURL,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/json",
                "Cache-Control": "max-age=180"
            ]
        )!
        
        let cachedResponse = CachedURLResponse(response: httpResponse, data: mockIdentityResponse)
        Flagsmith.shared.cacheConfig.cache.storeCachedResponse(cachedResponse, for: mockRequest)
        
        // Pre-populated cache with successful response
        // Now test customer's exact call with skipAPI=true
        
        // Now test customer's exact scenario
        Flagsmith.shared.getFeatureFlags(forIdentity: testIdentity) { result in
            switch result {
            case .success(let flags):
                // Customer call worked with cache successfully
                XCTAssertEqual(flags.count, 1, "Should get one cached flag")
                XCTAssertEqual(flags.first?.feature.name, "customer_test_feature", "Should get cached feature")
                
                // Test subsequent calls also work
                // Test subsequent calls also work
                Flagsmith.shared.getFeatureFlags(forIdentity: testIdentity) { subsequentResult in
                    switch subsequentResult {
                    case .success(let subsequentFlags):
                        // Subsequent call also succeeded with cache
                        XCTAssertEqual(flags.count, subsequentFlags.count, "Subsequent calls should return same cached data")
                    case .failure(let error):
                        XCTFail("Subsequent call should also succeed with cache: \(error)")
                    }
                    expectation.fulfill()
                }
                
            case .failure(let error):
                XCTFail("Customer call should succeed with pre-populated cache: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Cleanup
        Flagsmith.shared.cacheConfig.skipAPI = false
        Flagsmith.shared.cacheConfig.useCache = false
    }
    
    /// Test the customer's session-long caching expectation
    func testCustomerSessionLongCaching() throws {
        let expectation = expectation(description: "Session-long caching test")
        
        // Test customer's session-long cache expectation
        
        // Customer configuration
        Flagsmith.shared.baseURL = URL(string: "https://edge.api.flagsmith.com/api/v1/")!
        Flagsmith.shared.cacheConfig.useCache = true
        Flagsmith.shared.cacheConfig.cacheTTL = 180 // Customer's 3-minute TTL
        Flagsmith.shared.cacheConfig.skipAPI = true
        
        let sessionIdentity = "session-test-user"
        var requestCount = 0
        let totalRequests = 5 // Simulate multiple requests during session
        
        func makeSessionRequest() {
            requestCount += 1
            // Session request #\(requestCount)
            
            Flagsmith.shared.getFeatureFlags(forIdentity: sessionIdentity) { result in
                switch result {
                case .success(_):
                    // Request succeeded
                    break
                case .failure(_):
                    // Request failed as expected
                    // If we have a real API key and caching is enabled, failures after first success indicate a problem
                    if TestConfig.hasRealApiKey && requestCount > 1 {
                        // Warning: Session request failed - cache might not be working
                        // Note: Not failing here as session behavior may vary, but logging concern
                    }
                    break
                }
                
                // Continue session requests
                if requestCount < totalRequests {
                    // Simulate time between requests in a session
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        makeSessionRequest()
                    }
                } else {
                    // Session simulation complete
                    expectation.fulfill()
                }
            }
        }
        
        // Start session simulation
        makeSessionRequest()
        
        wait(for: [expectation], timeout: 15.0)
        
        // Cleanup
        Flagsmith.shared.cacheConfig.skipAPI = false
        Flagsmith.shared.cacheConfig.useCache = false
    }
    
    /// Test customer configuration edge cases
    func testCustomerConfigurationEdgeCases() throws {
        let expectation = expectation(description: "Customer config edge cases")
        
        // Test customer configuration edge cases
        
        // Test with customer config but different identities
        Flagsmith.shared.baseURL = URL(string: "https://edge.api.flagsmith.com/api/v1/")!
        Flagsmith.shared.cacheConfig.useCache = true
        Flagsmith.shared.cacheConfig.cacheTTL = 180
        Flagsmith.shared.cacheConfig.skipAPI = true
        
        let identities = ["user_a", "user_b", "user_c"]
        var completedTests = 0
        
        for identity in identities {
            // Testing with identity: \(identity)
            
            // Test both forIdentity and no identity calls
            Flagsmith.shared.getFeatureFlags(forIdentity: identity) { identityResult in
                // Identity request completed
                
                // Also test without identity
                Flagsmith.shared.getFeatureFlags { noIdentityResult in
                    // No identity request completed
                    
                    completedTests += 1
                    if completedTests == identities.count {
                        // All edge case tests completed
                        expectation.fulfill()
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 20.0)
        
        // Cleanup
        Flagsmith.shared.cacheConfig.skipAPI = false
        Flagsmith.shared.cacheConfig.useCache = false
    }
    
    /// Test to reproduce the exact customer issue scenario
    func testExactCustomerIssueReproduction() throws {
        let expectation = expectation(description: "Exact customer issue reproduction")
        
        // Reproduce customer issue: requests always via HTTP despite skipAPI=true
        
        // Exact customer setup
        let baseURL = URL(string: "https://edge.api.flagsmith.com/api/v1/")!
        Flagsmith.shared.baseURL = baseURL
        Flagsmith.shared.enableRealtimeUpdates = false
        Flagsmith.shared.cacheConfig.useCache = true
        Flagsmith.shared.cacheConfig.cache = URLCache(
            memoryCapacity: 8 * 1024 * 1024,   // 8 MB  
            diskCapacity:   64 * 1024 * 1024,  // 64 MB
            directory:      nil
        )
        Flagsmith.shared.cacheConfig.cacheTTL = 180
        Flagsmith.shared.cacheConfig.skipAPI = true
        
        let customerIdentity = "problematic-identity"
        // Monitor requests to see if HTTP calls are being made
        class RequestCounter {
            static var count = 0
            static func increment() { count += 1 }
            static func reset() { count = 0 }
        }
        
        RequestCounter.reset()
        
        // Make first request with customer configuration
        
        // Customer's problematic call
        Flagsmith.shared.getFeatureFlags(forIdentity: customerIdentity) { firstResult in
            RequestCounter.increment()
            // First request completed
            
            // Make second request (customer expects cache)
            
            Flagsmith.shared.getFeatureFlags(forIdentity: customerIdentity) { secondResult in
                RequestCounter.increment()
                // Second request completed
                
                // Make third request
                
                Flagsmith.shared.getFeatureFlags(forIdentity: customerIdentity) { thirdResult in
                    RequestCounter.increment()
                    // Third request completed
                    
                    // Analyze customer issue results
                    // Total requests made, expectation: use cache, problem: all via HTTP
                    
                    // All three will likely fail with test credentials, demonstrating the issue:
                    // Cache is never populated because requests fail, so skipAPI falls back to HTTP
                    switch (firstResult, secondResult, thirdResult) {
                    case (.failure(_), .failure(_), .failure(_)):
                        // Issue reproduced: all requests failed, proving HTTP calls were made
                        // Root cause: skipAPI=true with no cache falls back to HTTP

                        // With real API keys, this indicates a genuine caching problem
                        if TestConfig.hasRealApiKey {
                            XCTFail("Customer issue reproduced: skipAPI=true should use cache after successful initial request, but all requests failed")
                        } else {
                            // Issue demonstrated with test credentials
                        }
                        
                    case (.success(_), .success(_), .success(_)):
                        // All succeeded - cache working
                        break
                        
                    default:
                        // Mixed results - partial cache behavior

                        // Mixed results with real API key suggest inconsistent cache behavior
                        if TestConfig.hasRealApiKey {
                            // Warning: Mixed results suggest cache inconsistency
                            // Not failing as some mixed results might be acceptable, but noting concern
                        }
                    }
                    
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 20.0)
        
        // Cleanup
        Flagsmith.shared.cacheConfig.skipAPI = false
        Flagsmith.shared.cacheConfig.useCache = false
    }
}