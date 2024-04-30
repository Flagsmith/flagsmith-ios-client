//
//  FlagsmithAnalytics.swift
//  FlagsmithClient
//
//  Created by Daniel Wichett on 05/10/2021.
//

import Foundation

/// Internal analytics for the **FlagsmithClient**
class FlagsmithAnalytics {
    /// Indicates if analytics are enabled.
    var enableAnalytics: Bool = true
    /// How often analytics events are processed (in seconds).
    var flushPeriod: Int = 10 {
        didSet {
            setupTimer()
        }
    }

    private unowned let apiManager: APIManager
    private let EVENTS_KEY = "events"
    private var events: [String: Int] = [:]
    private var timer: Timer?

    init(apiManager: APIManager) {
        self.apiManager = apiManager
        events = UserDefaults.standard.dictionary(forKey: EVENTS_KEY) as? [String: Int] ?? [:]
        setupTimer()
    }

    /// Counts the instances of a `Flag` being queried.
    func trackEvent(flagName: String) {
        let current = events[flagName] ?? 0
        events[flagName] = current + 1
        saveEvents()
    }

    /// Invalidate and re-schedule timer for processing events
    ///
    /// On Apple (Darwin) platforms, this uses the Objective-C based
    /// target/selector message sending API.
    ///
    /// Non-Darwin systems will use the corelibs Foundation block-based
    /// api. Both platforms could use this approach, but the podspec
    /// declares iOS 8.0 as a minimum target, and that api is only
    /// available on 10+. (12.0 would be a good base in the future).
    private func setupTimer() {
        timer?.invalidate()
        #if canImport(ObjectiveC)
            timer = Timer.scheduledTimer(
                timeInterval: TimeInterval(flushPeriod),
                target: self,
                selector: #selector(postAnalyticsWhenEnabled(_:)),
                userInfo: nil,
                repeats: true
            )
        #else
            timer = Timer.scheduledTimer(
                withTimeInterval: TimeInterval(flushPeriod),
                repeats: true,
                block: { [weak self] _ in
                    self?.postAnalytics()
                }
            )
        #endif
    }

    /// Reset events after successful processing.
    private func reset() {
        events = [:]
        saveEvents()
    }

    /// Persist the events to storage.
    private func saveEvents() {
        UserDefaults.standard.set(events, forKey: EVENTS_KEY)
    }

    /// Send analytics to the api when enabled.
    private func postAnalytics() {
        guard enableAnalytics else {
            return
        }

        guard !events.isEmpty else {
            return
        }

        apiManager.request(.postAnalytics(events: events)) { [weak self] (result: Result<Void, Error>) in
            switch result {
            case .failure:
                print("Upload analytics failed")
            case .success:
                self?.reset()
            }
        }
    }

    #if canImport(ObjectiveC)
        /// Event triggered when timer fired.
        ///
        /// Exposed on Apple platforms to relay selector-based events
        @objc private func postAnalyticsWhenEnabled(_: Timer) {
            postAnalytics()
        }
    #endif
}
