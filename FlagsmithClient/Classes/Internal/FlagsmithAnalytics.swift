//
//  FlagsmithAnalytics.swift
//  FlagsmithClient
//
//  Created by Daniel Wichett on 05/10/2021.
//

import Foundation

/// Internal analytics for the **FlagsmithClient**
final class FlagsmithAnalytics: @unchecked Sendable {

    /// Indicates if analytics are enabled.
    private var _enableAnalytics: Bool = true
    var enableAnalytics:Bool {
        get {
            apiManager.propertiesSerialAccessQueue.sync { _enableAnalytics }
        }
        set {
            apiManager.propertiesSerialAccessQueue.sync {
                _enableAnalytics = newValue
            }
        }
    }

    private var _flushPeriod: Int = 10
    /// How often analytics events are processed (in seconds).
    var flushPeriod: Int {
        get {
            apiManager.propertiesSerialAccessQueue.sync { _flushPeriod }
        }
        set {
            apiManager.propertiesSerialAccessQueue.sync {
                _flushPeriod = newValue
            }
            setupTimer()
        }
    }

    private unowned let apiManager: APIManager
    private let EVENTS_KEY = "events"
    private var _events:[String:Int] = [:]
    private var events:[String:Int] {
        get {
            apiManager.propertiesSerialAccessQueue.sync { _events }
        }
        set {
            apiManager.propertiesSerialAccessQueue.sync {
                _events = newValue
            }
        }
    }
    private var _timer:Timer?
    private var timer:Timer? {
        get {
            apiManager.propertiesSerialAccessQueue.sync { _timer }
        }
        set {
            apiManager.propertiesSerialAccessQueue.sync {
                _timer = newValue
            }
        }
    }

    init(apiManager: APIManager) {
        self.apiManager = apiManager
        events = UserDefaults.standard.dictionary(forKey: EVENTS_KEY) as? [String:Int] ?? [:]
        setupTimer()
    }

    /// Counts the instances of a `Flag` being queried.
    func trackEvent(flagName:String) {
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

        apiManager.request(.postAnalytics(events: events)) { @Sendable [weak self] (result: Result<Void, Error>) in
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
    @objc private func postAnalyticsWhenEnabled(_ timer: Timer) {
        postAnalytics()
    }
#endif
}
