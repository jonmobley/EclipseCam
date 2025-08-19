//
//  OrientationManager.swift
//  EclipseCam
//
//  Created by Jon Mobley on 8/18/25.
//

import UIKit
import SwiftUI

class OrientationManager: ObservableObject {
    static let shared = OrientationManager()
    
    private init() {}
    
    private var supportedOrientations: UIInterfaceOrientationMask = .allButUpsideDown
    
    func setOrientation(_ orientation: UIInterfaceOrientationMask) {
        print("OrientationManager: Setting orientation to \(orientation)")
        supportedOrientations = orientation
        
        // Minimal approach - just update supported orientations
        // Avoid geometry updates that cause hangs
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }
    
    func setOrientation(_ orientation: UIInterfaceOrientation) {
        let mask: UIInterfaceOrientationMask
        switch orientation {
        case .portrait:
            mask = .portrait
        case .landscapeLeft:
            mask = .landscapeLeft
        case .landscapeRight:
            mask = .landscapeRight
        case .portraitUpsideDown:
            mask = .portraitUpsideDown
        default:
            mask = .allButUpsideDown
        }
        setOrientation(mask)
    }
    
    // Removed forceOrientation method - was causing hangs and conflicts
    
    func getSupportedOrientations() -> UIInterfaceOrientationMask {
        return supportedOrientations
    }
    
    func resetToFreeRotation() {
        print("OrientationManager: Resetting to free rotation")
        supportedOrientations = .allButUpsideDown
        
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }
    
    // Force the device to portrait orientation
    func forcePortrait() {
        print("OrientationManager: Forcing portrait orientation")
        supportedOrientations = .portrait
        
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }
}

// Extension to make UIInterfaceOrientationMask work with our enum
extension UIInterfaceOrientationMask {
    static func from(_ orientation: UIInterfaceOrientation) -> UIInterfaceOrientationMask {
        switch orientation {
        case .portrait:
            return .portrait
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .unknown:
            return .allButUpsideDown
        @unknown default:
            return .allButUpsideDown
        }
    }
}
