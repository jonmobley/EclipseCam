//
//  SettingsManager.swift
//  EclipseCam
//
//  Created by Jon Mobley on 8/18/25.
//

import SwiftUI
import Foundation

@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var enableRecording = false
    @Published var automaticallyRecord = false
    
    private let userDefaults = UserDefaults.standard
    
    private init() {
        loadSettings()
    }
    
    private func loadSettings() {
        enableRecording = userDefaults.bool(forKey: "enableRecording")
        automaticallyRecord = userDefaults.bool(forKey: "automaticallyRecord")
    }
    
    private func saveSettings() {
        userDefaults.set(enableRecording, forKey: "enableRecording")
        userDefaults.set(automaticallyRecord, forKey: "automaticallyRecord")
    }
    
    func updateEnableRecording(_ enabled: Bool) {
        enableRecording = enabled
        // If recording is disabled, also disable auto-record
        if !enabled {
            automaticallyRecord = false
        }
        saveSettings()
    }
    
    func updateAutomaticallyRecord(_ enabled: Bool) {
        automaticallyRecord = enabled
        // If auto-record is enabled, ensure recording is also enabled
        if enabled {
            enableRecording = true
        }
        saveSettings()
    }
}
