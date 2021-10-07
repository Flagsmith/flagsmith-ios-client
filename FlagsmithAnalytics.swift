//
//  FlagsmithAnalytics.swift
//  FlagsmithClient
//
//  Created by Daniel Wichett on 05/10/2021.
//

import Foundation
import UIKit

class FlagsmithAnalytics {
    
    static let shared = FlagsmithAnalytics()
    
    let EVENTS_KEY = "events"
    var events:[String:Int] = [:]
    
    var timer:Timer?
    
    init() {
        events = UserDefaults.standard.dictionary(forKey: EVENTS_KEY) as? [String:Int] ?? [:]
        setupTimer()
    }
    
    func setupTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(Flagsmith.shared.analyticsFlushPeriod), target: self, selector: #selector(postAnalytics(_:)), userInfo: nil, repeats: true)
    }
    
    func trackEvent(flagName:String) {
        let current = events[flagName] ?? 0
        events[flagName] = current + 1
        saveEvents()
    }
    
    func reset() {
        events = [:]
        saveEvents()
    }
    
    func saveEvents() {
        UserDefaults.standard.set(events, forKey: EVENTS_KEY)
    }
    
    @objc func postAnalytics(_ timer: Timer) {
        if Flagsmith.shared.enableAnalytics {
            if !events.isEmpty {
                Flagsmith.shared.postAnalytics() {
                    (result) in
                    switch result {
                    case .success( _):
                        self.reset()
                    case .failure( _):
                      print("Upload analytics failed")
                    }
                }
            }
        }
    }
}
