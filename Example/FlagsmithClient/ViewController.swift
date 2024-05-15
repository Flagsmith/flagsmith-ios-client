//
//  ViewController.swift
//  FlagsmithClient
//
//  Created by Tomash Tsiupiak on 06/20/2019.
//  Copyright (c) 2019 Tomash Tsiupiak. All rights reserved.
//

import UIKit
import FlagsmithClient
import AppTrackingTransparency
import AdSupport

class ViewController: UIViewController {
  
  override func viewDidLoad() {
      super.viewDidLoad()
      // Request user authorization for tracking
      ATTrackingManager.requestTrackingAuthorization { status in
          switch status {
          case .authorized:
              // Tracking authorization granted
              print("Tracking authorization granted")
          case .denied:
              // Tracking authorization denied
              print("Tracking authorization denied")
          case .restricted:
              // Tracking restricted
              print("Tracking restricted")
          case .notDetermined:
              // Tracking authorization not determined
              print("Tracking authorization not determined")
          @unknown default:
              // Handle other cases
              print("Unknown tracking authorization status")
          }
      }
  }

}
