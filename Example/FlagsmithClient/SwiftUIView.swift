//
//  SwiftUIView.swift
//  FlagsmithClient_Example
//
//  Created by Gareth Reese on 16/09/2024.
//  Copyright © 2024 CocoaPods. All rights reserved.
//

#if canImport(SwiftUI)
    import SwiftUI
#endif
import FlagsmithClient

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *)
struct SwiftUIView: View {
    @State private var flags: [Flag] = []
    @State private var isLoading = false
    @State private var identity: String = "test_user_123"
    @State private var logMessages: [String] = []
    @State private var cacheStatus: String = "Unknown"

    let flagsmith = Flagsmith.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerView
                configurationView
                identityInputView
                actionButtonsView
                testButtonsView
                loadingView
                debugLogView
                flagsDisplayView
                Spacer()
            }
        }
        .onAppear {
            setupInitialConfiguration()
        }
    }
    
    private var headerView: some View {
        Text("Flagsmith Testing Tool")
            .font(.title)
            .padding()
    }
    
    private var configurationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cache Configuration:")
                .font(.headline)
            Text("useCache: \(flagsmith.cacheConfig.useCache ? "✅" : "❌")")
            Text("skipAPI: \(flagsmith.cacheConfig.skipAPI ? "✅" : "❌")")
            Text("cacheTTL: \(Int(flagsmith.cacheConfig.cacheTTL))s")
            Text("enableRealtimeUpdates: \(flagsmith.enableRealtimeUpdates ? "✅" : "❌")")
            Text("Cache Status: \(cacheStatus)")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var identityInputView: some View {
        VStack(alignment: .leading) {
            Text("Identity:")
                .font(.headline)
            TextField("Enter identity", text: $identity)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.horizontal)
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 16) {
            Button("Apply Example Config") {
                applyExampleConfig()
            }
            .buttonStyle(.borderedProminent)
            
            Button("Clear Cache") {
                clearCache()
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var testButtonsView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Button("Test getFeatureFlags(forIdentity:)") {
                    testGetFeatureFlagsForIdentity()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Test hasFeatureFlag(forIdentity:)") {
                    testHasFeatureFlagForIdentity()
                }
                .buttonStyle(.borderedProminent)
            }
            
            HStack(spacing: 16) {
                Button("Test Cache Expiration") {
                    testCacheExpiration()
                }
                .buttonStyle(.bordered)
                
                Button("Force Refresh (No Cache)") {
                    testForceRefresh()
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        if isLoading {
            ProgressView()
                .padding()
        }
    }
    
    private var debugLogView: some View {
        VStack(alignment: .leading) {
            debugLogHeader
            debugLogScrollView
        }
        .padding(.horizontal)
    }
    
    private var debugLogHeader: some View {
        Text("Debug Log:")
            .font(.headline)
    }
    
    private var debugLogScrollView: some View {
        ScrollView {
            LazyVStack(alignment: .leading) {
                ForEach(logMessages.indices, id: \.self) { index in
                    debugLogRow(message: logMessages[index])
                }
            }
        }
        .frame(height: 150)
        .background(Color.black.opacity(0.05))
        .cornerRadius(4)
    }
    
    private func debugLogRow(message: String) -> some View {
        Text(message)
            .font(.system(size: 10))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private var flagsDisplayView: some View {
        if !flags.isEmpty {
            Text("Current Flags:")
                .font(.headline)
            List(flags, id: \.feature.name) { flag in
                HStack {
                    Text("\(flag.feature.name): \(flag.value)")
                        .font(.system(size: 12))
                    Spacer()
                    Text("\(flag.enabled ? "✅" : "❌")")
                }
            }
            .frame(height: 200)
        }
    }

    func setupInitialConfiguration() {
        addLog("App started - checking initial configuration")
        checkCacheStatus()
    }
    
    func applyExampleConfig() {
        addLog("Applying example configuration...")
        
        // Example cache configuration for testing
        flagsmith.enableRealtimeUpdates = false
        flagsmith.cacheConfig.useCache = true
        flagsmith.cacheConfig.cache = URLCache(
            memoryCapacity: 8 * 1024 * 1024,   // 8 MB
            diskCapacity: 64 * 1024 * 1024,    // 64 MB
            directory: nil
        )
        flagsmith.cacheConfig.cacheTTL = 180
        flagsmith.cacheConfig.skipAPI = true
        
        addLog("Configuration applied:")
        addLog("- enableRealtimeUpdates: \(flagsmith.enableRealtimeUpdates)")
        addLog("- useCache: \(flagsmith.cacheConfig.useCache)")
        addLog("- skipAPI: \(flagsmith.cacheConfig.skipAPI)")
        addLog("- cacheTTL: \(Int(flagsmith.cacheConfig.cacheTTL))s")
        addLog("- Cache: 8MB/64MB URLCache")
        
        checkCacheStatus()
    }
    
    func clearCache() {
        addLog("Clearing cache...")
        flagsmith.cacheConfig.cache.removeAllCachedResponses()
        addLog("Cache cleared")
        checkCacheStatus()
    }
    
    func checkCacheStatus() {
        let memoryUsage = flagsmith.cacheConfig.cache.currentMemoryUsage
        let diskUsage = flagsmith.cacheConfig.cache.currentDiskUsage
        cacheStatus = "Memory: \(memoryUsage/1024)KB, Disk: \(diskUsage/1024)KB"
        addLog("Cache status: \(cacheStatus)")
    }
    
    func testGetFeatureFlagsForIdentity() {
        addLog("Testing getFeatureFlags(forIdentity: \"\(identity)\")...")
        isLoading = true
        
        let startTime = Date()
        
        Task {
            do {
                let fetchedFlags = try await flagsmith.getFeatureFlags(forIdentity: identity)
                let responseTime = Date().timeIntervalSince(startTime)
                
                DispatchQueue.main.async {
                    self.flags = fetchedFlags
                    self.isLoading = false
                    self.addLog("✅ Success in \(String(format: "%.2f", responseTime))s - got \(fetchedFlags.count) flags")
                    self.checkCacheStatus()
                    
                    // Log some flag details
                    for flag in fetchedFlags.prefix(3) {
                        self.addLog("  - \(flag.feature.name): \(flag.value)")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.addLog("❌ Error: \(error)")
                }
            }
        }
    }
    
    func testHasFeatureFlagForIdentity() {
        addLog("Testing hasFeatureFlag(withID: 'feature_a', forIdentity: \"\(identity)\")...")
        isLoading = true
        
        let startTime = Date()
        
        Task {
            do {
                let hasFlag = try await flagsmith.hasFeatureFlag(withID: "feature_a", forIdentity: identity)
                let responseTime = Date().timeIntervalSince(startTime)
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.addLog("✅ hasFeatureFlag result in \(String(format: "%.2f", responseTime))s: \(hasFlag)")
                    self.checkCacheStatus()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.addLog("❌ Error: \(error)")
                }
            }
        }
    }
    
    func testCacheExpiration() {
        addLog("Testing cache expiration behavior...")
        addLog("Current cache TTL: \(Int(flagsmith.cacheConfig.cacheTTL))s")
        addLog("Setting TTL to 5 seconds for quick testing")
        
        // Temporarily set a short TTL for testing
        let originalTTL = flagsmith.cacheConfig.cacheTTL
        flagsmith.cacheConfig.cacheTTL = 5 // 5 seconds
        
        testGetFeatureFlagsForIdentity()
        
        // Schedule a test in 6 seconds to verify expiration
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            self.addLog("Testing after 6 seconds (should be expired)...")
            self.testGetFeatureFlagsForIdentity()
            
            // Restore original TTL
            self.flagsmith.cacheConfig.cacheTTL = originalTTL
            self.addLog("Restored TTL to \(Int(originalTTL))s")
        }
    }
    
    func testForceRefresh() {
        addLog("Testing force refresh (temporarily disabling cache)...")
        
        let originalUseCache = flagsmith.cacheConfig.useCache
        flagsmith.cacheConfig.useCache = false
        
        testGetFeatureFlagsForIdentity()
        
        // Restore cache setting
        flagsmith.cacheConfig.useCache = originalUseCache
        addLog("Restored cache setting: useCache=\(originalUseCache)")
    }
    
    func addLog(_ message: String) {
        let timestamp = DateFormatter().apply {
            $0.dateFormat = "HH:mm:ss.SSS"
        }.string(from: Date())
        
        logMessages.append("[\(timestamp)] \(message)")
        
        // Keep only last 50 messages
        if logMessages.count > 50 {
            logMessages.removeFirst(logMessages.count - 50)
        }
    }
}

extension DateFormatter {
    func apply(_ closure: (DateFormatter) -> Void) -> DateFormatter {
        closure(self)
        return self
    }
}
