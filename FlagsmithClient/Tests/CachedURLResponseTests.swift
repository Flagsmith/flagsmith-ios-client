//
//  CachedURLResponseTests.swift
//  FlagsmithClientTests
//
//  Created for testing CachedURLResponse TTL extension
//

@testable import FlagsmithClient
import XCTest

final class CachedURLResponseTests: FlagsmithClientTestCase {
    
    /// Test that our CachedURLResponse extension correctly sets TTL headers
    func testCachedURLResponseTTLExtension() throws {
        let mockURL = URL(string: "https://example.com/test")!
        
        // Original response without cache headers
        let originalHttpResponse = HTTPURLResponse(
            url: mockURL,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/json",
                "Server": "nginx"
            ]
        )!
        
        let mockData = "test data".data(using: .utf8)!
        let originalCachedResponse = CachedURLResponse(response: originalHttpResponse, data: mockData)
        
        // Test with various TTL durations
        let testDurations = [0, 1, 60, 300, 3600, 86400] // 0, 1s, 1min, 5min, 1hour, 1day
        
        for duration in testDurations {
            let modifiedResponse = originalCachedResponse.response(withExpirationDuration: duration)
            
            guard let httpResponse = modifiedResponse.response as? HTTPURLResponse else {
                XCTFail("Modified response should be HTTPURLResponse")
                continue
            }
            
            let cacheControl = httpResponse.allHeaderFields["Cache-Control"] as? String
            let expires = httpResponse.allHeaderFields["Expires"] as? String
            let sMaxAge = httpResponse.allHeaderFields["s-maxage"] as? String
            
            // Verify Cache-Control header is set correctly
            let expectedMaxAge = duration == 0 ? 31_536_000 : duration // 1 year for 0
            XCTAssertEqual(cacheControl, "max-age=\(expectedMaxAge)", 
                          "Cache-Control should be set correctly for duration \(duration)")
            
            // Verify that Expires and s-maxage headers are removed
            XCTAssertNil(expires, "Expires header should be removed for duration \(duration)")
            XCTAssertNil(sMaxAge, "s-maxage header should be removed for duration \(duration)")
            
            // Verify other headers are preserved
            let contentType = httpResponse.allHeaderFields["Content-Type"] as? String
            let server = httpResponse.allHeaderFields["Server"] as? String
            XCTAssertEqual(contentType, "application/json", "Content-Type should be preserved")
            XCTAssertEqual(server, "nginx", "Server header should be preserved")
            
            // Verify data is unchanged
            XCTAssertEqual(modifiedResponse.data, mockData, "Data should be unchanged for duration \(duration)")
        }
    }
    
    /// Test that the extension handles server cache headers correctly
    func testCachedURLResponseOverrideServerHeaders() throws {
        let mockURL = URL(string: "https://example.com/test")!
        
        // Response with existing cache headers from server
        let serverHttpResponse = HTTPURLResponse(
            url: mockURL,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/json",
                "Cache-Control": "max-age=30, private", // Server wants 30 seconds
                "Expires": "Thu, 01 Dec 2023 16:00:00 GMT", // Server sets expires
                "s-maxage": "60" // Server sets s-maxage
            ]
        )!
        
        let mockData = "server cache test".data(using: .utf8)!
        let serverCachedResponse = CachedURLResponse(response: serverHttpResponse, data: mockData)
        
        // Override with our TTL (5 minutes)
        let overriddenResponse = serverCachedResponse.response(withExpirationDuration: 300)
        
        guard let httpResponse = overriddenResponse.response as? HTTPURLResponse else {
            XCTFail("Overridden response should be HTTPURLResponse")
            return
        }
        
        // Verify our TTL overrides server's cache settings
        let cacheControl = httpResponse.allHeaderFields["Cache-Control"] as? String
        let expires = httpResponse.allHeaderFields["Expires"] as? String
        let sMaxAge = httpResponse.allHeaderFields["s-maxage"] as? String
        
        XCTAssertEqual(cacheControl, "max-age=300", "Our TTL should override server's Cache-Control")
        XCTAssertNil(expires, "Server's Expires header should be removed")
        XCTAssertNil(sMaxAge, "Server's s-maxage header should be removed")
        
        // Verify other headers remain unchanged
        let contentType = httpResponse.allHeaderFields["Content-Type"] as? String
        XCTAssertEqual(contentType, "application/json", "Content-Type should be preserved")
    }
    
    /// Test edge cases in the TTL extension
    func testCachedURLResponseEdgeCases() throws {
        let mockURL = URL(string: "https://example.com/test")!
        let mockData = "edge case test".data(using: .utf8)!
        
        // Test with missing headers
        let minimalHttpResponse = HTTPURLResponse(
            url: mockURL,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: nil // No headers
        )!
        
        let minimalCachedResponse = CachedURLResponse(response: minimalHttpResponse, data: mockData)
        let modifiedMinimalResponse = minimalCachedResponse.response(withExpirationDuration: 60)
        
        if let httpResponse = modifiedMinimalResponse.response as? HTTPURLResponse {
            let cacheControl = httpResponse.allHeaderFields["Cache-Control"] as? String
            XCTAssertEqual(cacheControl, "max-age=60", "Should add Cache-Control even when no headers exist")
        }
        
        // Test with negative duration (edge case)
        let negativeResponse = minimalCachedResponse.response(withExpirationDuration: -1)
        if let httpResponse = negativeResponse.response as? HTTPURLResponse {
            let cacheControl = httpResponse.allHeaderFields["Cache-Control"] as? String
            // Should handle negative values gracefully (might set to 0 or some default)
            XCTAssertNotNil(cacheControl, "Should handle negative duration gracefully")
            print("Negative duration resulted in: \(cacheControl ?? "nil")")
        }
        
        // Test with very large duration
        let largeDuration = Int.max
        let largeResponse = minimalCachedResponse.response(withExpirationDuration: largeDuration)
        if let httpResponse = largeResponse.response as? HTTPURLResponse {
            let cacheControl = httpResponse.allHeaderFields["Cache-Control"] as? String
            XCTAssertNotNil(cacheControl, "Should handle very large duration")
            print("Large duration resulted in: \(cacheControl ?? "nil")")
        }
    }
    
    /// Test thread safety of the TTL extension (basic test)
    func testCachedURLResponseThreadSafety() throws {
        let mockURL = URL(string: "https://example.com/test")!
        let mockData = "thread safety test".data(using: .utf8)!
        
        let httpResponse = HTTPURLResponse(
            url: mockURL,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        
        let cachedResponse = CachedURLResponse(response: httpResponse, data: mockData)
        
        let expectation = self.expectation(description: "Thread safety test")
        expectation.expectedFulfillmentCount = 10
        
        // Run multiple concurrent modifications
        for i in 0..<10 {
            DispatchQueue.global().async {
                let ttl = 60 + i // Different TTL for each thread
                let modifiedResponse = cachedResponse.response(withExpirationDuration: ttl)
                
                // Verify the modification worked
                if let httpResp = modifiedResponse.response as? HTTPURLResponse {
                    let cacheControl = httpResp.allHeaderFields["Cache-Control"] as? String
                    XCTAssertEqual(cacheControl, "max-age=\(ttl)", "TTL should be set correctly in thread \(i)")
                }
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
