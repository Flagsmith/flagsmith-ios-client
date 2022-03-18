//
//  FlagsmithAnalytics.swift
//  FlagsmithClient
//
//  Created by Daniel Wichett on 05/10/2021.
//

import Foundation

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
  private var events:[String:Int] = [:]
  private var timer:Timer?
  
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
  private func setupTimer() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(
      timeInterval: TimeInterval(flushPeriod),
      target: self,
      selector: #selector(postAnalytics(_:)),
      userInfo: nil,
      repeats: true
    )
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
  @objc private func postAnalytics(_ timer: Timer) {
    guard enableAnalytics else {
      return
    }
  
    guard !events.isEmpty else {
      return
    }
  
    apiManager.request(
      .postAnalytics(events: events),
      emptyResponse: true
    ) { [weak self] (result: Result<String, Error>) in
      switch result {
      case .failure:
        print("Upload analytics failed")
      case .success:
        self?.reset()
      }
    }
  }
}
