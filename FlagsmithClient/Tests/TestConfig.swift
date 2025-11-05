//
//  TestConfig.swift
//  FlagsmithClientTests
//
//  Test configuration for API keys and test settings
//

import Foundation

struct TestConfig {
    /// Real API key for integration testing
    /// Set via environment variable FLAGSMITH_TEST_API_KEY or falls back to test-config.json
    static let apiKey: String = {
        // First priority: environment variable
        if let envKey = ProcessInfo.processInfo.environment["FLAGSMITH_TEST_API_KEY"],
           !envKey.isEmpty {
            return envKey
        }

        // Second priority: test-config.json file
        // SPM puts test resources in a separate resource bundle in the same directory as the xctest bundle
        let testBundle = Bundle(for: TestConfigObjC.self)
        let bundleName = "FlagsmithClient_FlagsmithClientTests"
        let testBundleURL = URL(fileURLWithPath: testBundle.bundlePath)
        let resourceBundleURL = testBundleURL.deletingLastPathComponent().appendingPathComponent("\(bundleName).bundle")

        if let resourceBundle = Bundle(url: resourceBundleURL),
           let path = resourceBundle.path(forResource: "test-config", ofType: "json"),
           let data = FileManager.default.contents(atPath: path),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let key = json["apiKey"] as? String,
           !key.isEmpty {
            return key
        }

        // Fallback to mock key for tests that don't need real API
        return "mock-test-api-key"
    }()
    
    /// Whether we have a real API key available
    static var hasRealApiKey: Bool {
        return apiKey != "mock-test-api-key"
    }
    
    /// Base URL for testing (can be overridden)
    static let baseURL = URL(string: "https://edge.api.flagsmith.com/api/v1/")!
    
    /// Test identity for consistent testing
    static let testIdentity = "test-user-integration"
}

// Helper for Objective-C bridge in case it's needed
@objc class TestConfigObjC: NSObject {
    @objc static let apiKey = TestConfig.apiKey
    @objc static let hasRealApiKey = TestConfig.hasRealApiKey
}
