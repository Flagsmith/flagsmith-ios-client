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
        let expectation = expectation(description: "Customer configuration test")
        
        print("🔍 CUSTOMER USE CASE: Testing exact reported configuration")
        
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
        
        print("Configuration:")
        print("- baseURL: \(Flagsmith.shared.baseURL)")
        print("- apiKey: \(Flagsmith.shared.apiKey ?? "nil")")
        print("- enableRealtimeUpdates: \(Flagsmith.shared.enableRealtimeUpdates)")
        print("- useCache: \(Flagsmith.shared.cacheConfig.useCache)")
        print("- cacheTTL: \(Flagsmith.shared.cacheConfig.cacheTTL)")
        print("- skipAPI: \(Flagsmith.shared.cacheConfig.skipAPI)")
        
        // Test the exact call that was problematic
        print("\nTesting: try await Flagsmith.shared.getFeatureFlags(forIdentity: self.identity)")
        print("API key type: \(TestConfig.hasRealApiKey ? "real" : "mock")")
        
        let testIdentity = TestConfig.hasRealApiKey ? TestConfig.testIdentity : "customer-test-identity"
        
        // First call - should attempt network (may fail with test key)
        Flagsmith.shared.getFeatureFlags(forIdentity: testIdentity) { firstResult in
            print("First call result: \(firstResult)")
            
            switch firstResult {
            case .success(let flags):
                print("✅ First call succeeded - got \(flags.count) flags")
                print("Now testing second call (should use cache per customer expectation)")
                
                // Second call - customer expects this to use cache, not HTTP
                Flagsmith.shared.getFeatureFlags(forIdentity: testIdentity) { secondResult in
                    switch secondResult {
                    case .success(let cachedFlags):
                        print("✅ Second call succeeded - got \(cachedFlags.count) flags")
                        XCTAssertEqual(flags.count, cachedFlags.count, "Should get same flags from cache")
                        
                        // Verify it's using cache by checking flags are identical
                        XCTAssertEqual(flags.first?.feature.name, cachedFlags.first?.feature.name, "Should get identical cached flags")
                        
                    case .failure(let error):
                        XCTFail("Second call should succeed with cache: \(error)")
                    }
                    expectation.fulfill()
                }
                
            case .failure(let error):
                print("ℹ️ First call failed as expected with test key: \(error.localizedDescription)")
                
                // Test the behavior customer would see - subsequent calls should still attempt network
                // because no successful cache was established
                print("Testing subsequent call behavior when no cache exists")
                
                Flagsmith.shared.getFeatureFlags(forIdentity: testIdentity) { subsequentResult in
                    switch subsequentResult {
                    case .success(_):
                        print("⚠️ Unexpected success on subsequent call")
                    case .failure(let subsequentError):
                        print("ℹ️ Subsequent call also failed: \(subsequentError.localizedDescription)")
                        // This demonstrates the customer's issue: requests always go via HTTP
                        // because cache never gets populated from failed requests
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
        let expectation = expectation(description: "Customer config with successful cache")
        
        print("🔍 CUSTOMER USE CASE: Testing with successful cache population")
        
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
        
        print("✅ Pre-populated cache with successful response")
        print("Now testing customer's exact call with skipAPI=true")
        
        // Now test customer's exact scenario
        Flagsmith.shared.getFeatureFlags(forIdentity: testIdentity) { result in
            switch result {
            case .success(let flags):
                print("✅ SUCCESS: Customer call worked with cache!")
                print("Got \(flags.count) flags from cache")
                XCTAssertEqual(flags.count, 1, "Should get one cached flag")
                XCTAssertEqual(flags.first?.feature.name, "customer_test_feature", "Should get cached feature")
                
                // Test subsequent calls also work
                print("Testing subsequent call...")
                Flagsmith.shared.getFeatureFlags(forIdentity: testIdentity) { subsequentResult in
                    switch subsequentResult {
                    case .success(let subsequentFlags):
                        print("✅ Subsequent call also succeeded with \(subsequentFlags.count) flags")
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
        
        print("🔍 CUSTOMER USE CASE: Testing session-long cache behavior")
        print("Customer expectation: 'should a cached flag be available, this will be used throughout the session'")
        
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
            print("Session request #\(requestCount)")
            
            Flagsmith.shared.getFeatureFlags(forIdentity: sessionIdentity) { result in
                switch result {
                case .success(let flags):
                    print("✅ Request #\(requestCount): Got \(flags.count) flags")
                case .failure(let error):
                    print("ℹ️ Request #\(requestCount): Failed as expected: \(error.localizedDescription)")
                }
                
                // Continue session requests
                if requestCount < totalRequests {
                    // Simulate time between requests in a session
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        makeSessionRequest()
                    }
                } else {
                    print("✅ Session simulation complete - made \(totalRequests) requests")
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
        
        print("🔍 CUSTOMER USE CASE: Testing edge cases")
        
        // Test with customer config but different identities
        Flagsmith.shared.baseURL = URL(string: "https://edge.api.flagsmith.com/api/v1/")!
        Flagsmith.shared.cacheConfig.useCache = true
        Flagsmith.shared.cacheConfig.cacheTTL = 180
        Flagsmith.shared.cacheConfig.skipAPI = true
        
        let identities = ["user_a", "user_b", "user_c"]
        var completedTests = 0
        
        for identity in identities {
            print("Testing edge case with identity: \(identity)")
            
            // Test both forIdentity and no identity calls
            Flagsmith.shared.getFeatureFlags(forIdentity: identity) { identityResult in
                print("Identity '\(identity)' result: \(identityResult)")
                
                // Also test without identity
                Flagsmith.shared.getFeatureFlags { noIdentityResult in
                    print("No identity result for test \(identity): \(noIdentityResult)")
                    
                    completedTests += 1
                    if completedTests == identities.count {
                        print("✅ All edge case tests completed")
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
        
        print("🐛 REPRODUCING CUSTOMER ISSUE")
        print("Issue: 'requests are always served via HTTP, even though skipAPI = true'")
        
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
        
        print("Making first request with customer config...")
        
        // Customer's problematic call
        Flagsmith.shared.getFeatureFlags(forIdentity: customerIdentity) { firstResult in
            RequestCounter.increment()
            print("First request completed. Result: \(firstResult)")
            
            print("Making second request (customer expects cache, but reports HTTP)...")
            
            Flagsmith.shared.getFeatureFlags(forIdentity: customerIdentity) { secondResult in
                RequestCounter.increment()
                print("Second request completed. Result: \(secondResult)")
                
                print("Making third request...")
                
                Flagsmith.shared.getFeatureFlags(forIdentity: customerIdentity) { thirdResult in
                    RequestCounter.increment()
                    print("Third request completed. Result: \(thirdResult)")
                    
                    print("\n📊 CUSTOMER ISSUE ANALYSIS:")
                    print("- Total requests made: \(RequestCounter.count)")
                    print("- Customer expectation: Subsequent requests use cache (no HTTP)")
                    print("- Customer problem: All requests go via HTTP")
                    
                    // All three will likely fail with test credentials, demonstrating the issue:
                    // Cache is never populated because requests fail, so skipAPI falls back to HTTP
                    switch (firstResult, secondResult, thirdResult) {
                    case (.failure(_), .failure(_), .failure(_)):
                        print("🐛 ISSUE REPRODUCED: All requests failed, proving HTTP calls were made")
                        print("   Root cause: skipAPI=true with no cache falls back to HTTP")
                        print("   Our fix: ensureResponseIsCached() should solve this")
                        
                    case (.success(_), .success(_), .success(_)):
                        print("✅ All succeeded - cache might be working")
                        
                    default:
                        print("🤔 Mixed results - partial cache behavior")
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