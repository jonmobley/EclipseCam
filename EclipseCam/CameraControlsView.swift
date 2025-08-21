//
//  CameraControlsView.swift
//  EclipseCam
//
//  Created by Assistant on 8/18/25.
//

import SwiftUI
import AVFoundation

struct CameraControlsView: View {
    @ObservedObject var cameraManager: CameraManager
    @StateObject private var settings = SettingsManager.shared
    let onBack: () -> Void
    let orientationMode: OrientationMode
    
    var body: some View {
        ZStack {
            // Orientation-aware UI Controls
            if orientationMode == .landscape {
                landscapeControlsLayout
            } else {
                portraitControlsLayout
            }
        }
        .alert(cameraManager.alertTitle, isPresented: $cameraManager.showingAlert) {
            Button("OK") { }
        } message: {
            Text(cameraManager.alertMessage)
        }
    }
    
    // MARK: - Landscape Layout
    private var landscapeControlsLayout: some View {
        ZStack {
            // Bottom Left Exit Button
            VStack {
                Spacer()
                
                HStack {
                    exitButton
                        .padding(.leading, 20)
                        .padding(.bottom, 20)
                    
                    Spacer()
                }
            }
            
            // Right Side Button Column
            HStack {
                Spacer()
                
                VStack(spacing: 30) {
                    // Camera Switch Button - Top
                    cameraSwitchButton
                    
                    // Record Button - Center (only show if recording is enabled)
                    if settings.enableRecording {
                        recordButton
                    }
                    
                    Spacer()
                }
                .padding(.trailing, 20)
            }
            
            // Recording Timer - Top Center (only show if recording)
            if settings.enableRecording && cameraManager.isRecording {
                VStack {
                    recordingTimerView
                        .padding(.top, 20)
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Portrait Layout
    private var portraitControlsLayout: some View {
        VStack {
            // Top Controls
            HStack {
                // Left side - Exit button
                exitButton
                
                Spacer()
                
                // Right side - Recording Timer
                if settings.enableRecording && cameraManager.isRecording {
                    recordingTimerView
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 50)
            
            Spacer()
            
            // Bottom Controls
            HStack {
                Spacer()
                
                // Record Button - Bottom Center (only show if recording is enabled)
                if settings.enableRecording {
                    recordButton
                }
                
                Spacer()
                
                // Camera Switch Button - Bottom Right
                cameraSwitchButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - UI Components
    
    private var exitButton: some View {
        Button(action: {
            // Stop recording if currently recording before returning to main page
            if cameraManager.isRecording {
                cameraManager.stopRecording()
            }
            onBack()
        }) {
            ZStack {
                // Background circle (grey)
                Circle()
                    .fill(Color.gray.opacity(0.8))
                    .frame(width: 36, height: 36)
                
                // Border circle
                Circle()
                    .stroke(Color.gray, lineWidth: 1)
                    .frame(width: 36, height: 36)
                
                // X icon
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var cameraSwitchButton: some View {
        Button(action: {
            cameraManager.switchCamera()
        }) {
            ZStack {
                // White border ring
                Circle()
                    .fill(Color.white)
                    .frame(width: 80, height: 80)
                
                // Background circle
                Circle()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: 70, height: 70)
                
                // Camera switch icon
                Image(systemName: "camera.rotate.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .opacity(cameraManager.isRecording ? 0.5 : 1.0)
    }
    
    private var recordButton: some View {
        Button(action: {
            if cameraManager.isRecording {
                cameraManager.stopRecording()
            } else {
                cameraManager.startRecording()
            }
        }) {
            ZStack {
                // White border ring
                Circle()
                    .fill(Color.white)
                    .frame(width: 80, height: 80)
                
                // Red circle
                Circle()
                    .fill(Color.red)
                    .frame(width: 70, height: 70)
                
                // White square when recording
                if cameraManager.isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private var recordingTimerView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            
            Text(formatRecordingTime(cameraManager.recordingDuration))
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(20)
    }
    
    // MARK: - Helper Methods
    
    private func formatRecordingTime(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
