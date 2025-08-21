//
//  SettingsManager.swift
//  EclipseCam
//
//  Created by Assistant on 8/18/25.
//

import Foundation
import SwiftUI

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // Recording Settings
    @Published var enableRecording: Bool {
        didSet {
            UserDefaults.standard.set(enableRecording, forKey: "enableRecording")
            // If recording is disabled, also disable auto-record
            if !enableRecording {
                automaticallyRecord = false
            }
        }
    }
    
    @Published var automaticallyRecord: Bool {
        didSet {
            UserDefaults.standard.set(automaticallyRecord, forKey: "automaticallyRecord")
        }
    }
    
    private init() {
        // Load settings from UserDefaults
        self.enableRecording = UserDefaults.standard.bool(forKey: "enableRecording")
        self.automaticallyRecord = UserDefaults.standard.bool(forKey: "automaticallyRecord")
        
        // Set defaults if first launch
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            self.enableRecording = false // Default to disabled for safety
            self.automaticallyRecord = false
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
    }
    
    // Helper methods for updating settings
    func updateEnableRecording(_ enabled: Bool) {
        enableRecording = enabled
    }
    
    func updateAutomaticallyRecord(_ enabled: Bool) {
        // Only allow auto-record if recording is enabled
        if enableRecording {
            automaticallyRecord = enabled
        }
    }
}
