//
//  EclipseCamApp.swift
//  EclipseCam
//
//  Created by Jon Mobley on 8/18/25.
//

import SwiftUI

@main
struct EclipseCamApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark) // Better for AirPlay
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return OrientationManager.shared.getSupportedOrientations()
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Keep screen awake during live events
        UIApplication.shared.isIdleTimerDisabled = true
        return true
    }
}
