//
//  AppDelegate.swift
//  FlagsmithClient
//
//  Created by Tomash Tsiupiak on 06/20/2019.
//  Copyright (c) 2019 Tomash Tsiupiak. All rights reserved.
//

import UIKit
import FlagsmithClient

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  
  var window: UIWindow?
  
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Override point for customization after application launch.
    Flagsmith.shared.apiKey = "<add your API key from the Flagsmith settings page>"
      
    // set default flags
    Flagsmith.shared.defaultFlags = [Flag(featureName: "feature_a", enabled: false),
                                     Flag(featureName: "font_size", intValue:12, enabled: true),
                                     Flag(featureName: "my_name", stringValue:"Testing", enabled: true)]
    
    // set cache on / off (defaults to off)
    Flagsmith.shared.useCache = true
    
    // set custom cache to use (defaults to shared URLCache)
    //Flagsmith.shared.cache = <CUSTOM_CACHE>

    // set skip API on / off (defaults to off)
    Flagsmith.shared.skipAPI = false

    // set cache TTL in seconds (defaults to 0, i.e. infinite)
    Flagsmith.shared.cacheTTL = 90

    // set analytics on or off
    Flagsmith.shared.enableAnalytics = true
    
    // set the analytics flush period in seconds
    Flagsmith.shared.analyticsFlushPeriod = 10
    
    Flagsmith.shared.getFeatureFlags() { (result) in
      print(result)
    }
    Flagsmith.shared.hasFeatureFlag(withID: "freeze_delinquent_accounts") { (result) in
      print(result)
    }
    //Flagsmith.shared.setTrait(Trait(key: "<my_key>", value: "<my_value>"), forIdentity: "<my_identity>") { (result) in print(result) }
    //Flagsmith.shared.getIdentity("<my_key>") { (result) in print(result) }
    return true
  }
  
  func applicationWillResignActive(_ application: UIApplication) {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
  }
  
  func applicationDidEnterBackground(_ application: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
  }
  
  func applicationWillEnterForeground(_ application: UIApplication) {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
  }
  
  func applicationDidBecomeActive(_ application: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
  }
  
  func applicationWillTerminate(_ application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
  }
  
  #if swift(>=5.5.2)
  /// (Example) Setup the app based on the available feature flags.
  ///
  /// **Flagsmith** supports the Swift Concurrency feature `async`/`await`.
  /// Requests and logic can be handled in a streamlined order,
  /// eliminating the need to nest multiple completion handlers.
  @available(iOS 13.0, *)
  func determineAppConfiguration() async {
    let flagsmith = Flagsmith.shared
  
    do {
      if try await flagsmith.hasFeatureFlag(withID: "ab_test_enabled") {
        if let theme = try await flagsmith.getValueForFeature(withID: "app_theme") {
          setTheme(theme)
        } else {
          let flags = try await flagsmith.getFeatureFlags()
          processFlags(flags)
        }
      } else {
        let trait = Trait(key: "selected_tint_color", value: "orange")
        let identity = "4DDBFBCA-3B6E-4C59-B107-954F84FD7F6D"
        try await flagsmith.setTrait(trait, forIdentity: identity)
      }
    } catch {
        print(error)
    }
  }
  
  func setTheme(_ theme: TypedValue) {}
  func processFlags(_ flags: [Flag]) {}
  #endif
}
