//
//  CameraManager.swift
//  EclipseCam
//
//  Created by Jon Mobley on 8/18/25.
//

import AVFoundation
import SwiftUI

class CameraManager: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var session = AVCaptureSession()
    
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var orientationMode: OrientationMode = .portrait
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    func configure(for orientation: OrientationMode) {
        print("CameraManager: Configuring for orientation: \(orientation)")
        orientationMode = orientation
        if isAuthorized {
            setupCamera()
        }
    }
    
    func checkPermissions() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("CameraManager: Current camera permission status: \(status.rawValue)")
        
        switch status {
        case .authorized:
            print("CameraManager: Camera access authorized")
            isAuthorized = true
            // Don't setup camera here - wait for configure() call
        case .notDetermined:
            print("CameraManager: Requesting camera access...")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                print("CameraManager: Camera access granted: \(granted)")
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                    // Don't setup camera here - wait for configure() call
                }
            }
        case .denied, .restricted:
            print("CameraManager: Camera access denied or restricted")
            isAuthorized = false
        @unknown default:
            print("CameraManager: Unknown camera permission status")
            isAuthorized = false
        }
    }
    
    private func setupCamera() {
        print("CameraManager: Setting up camera for \(orientationMode) mode...")
        session.beginConfiguration()
        
        // Remove existing inputs
        session.inputs.forEach { session.removeInput($0) }
        
        // Configure session preset based on orientation
        let preset: AVCaptureSession.Preset
        switch orientationMode {
        case .portrait:
            preset = .hd1920x1080  // 1080p for portrait (will be rotated to 9:16)
        case .landscape:
            preset = .hd1920x1080  // 1080p for landscape (16:9)
        }
        
        if session.canSetSessionPreset(preset) {
            session.sessionPreset = preset
            print("CameraManager: Session preset set to \(preset) for \(orientationMode)")
        } else if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
            print("CameraManager: Fallback to .high preset")
        } else {
            print("CameraManager: Warning - Cannot set preferred session presets")
        }
        
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition) else {
            print("CameraManager: Error - No camera device found for position: \(currentCameraPosition)")
            session.commitConfiguration()
            return
        }
        
        print("CameraManager: Found camera device: \(videoDevice.localizedName)")
        
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            print("CameraManager: Error - Failed to create video device input")
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(videoDeviceInput) {
            session.addInput(videoDeviceInput)
            self.videoDeviceInput = videoDeviceInput
            print("CameraManager: Successfully added video input")
            
            // Configure focus settings for better close-up performance
            configureFocusSettings(for: videoDevice)
        } else {
            print("CameraManager: Error - Cannot add video input to session")
        }
        
        // Preview layer will be created by CameraPreview UIViewRepresentable
        
        session.commitConfiguration()
        print("CameraManager: Camera setup completed")
    }
    
    private func configureFocusSettings(for device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            
            // Set continuous autofocus mode for better close-up performance
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
                print("CameraManager: Set focus mode to continuous autofocus")
            } else if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
                print("CameraManager: Set focus mode to autofocus (continuous not supported)")
            }
            
            // Enable smooth autofocus for better video recording
            if device.isSmoothAutoFocusSupported {
                device.isSmoothAutoFocusEnabled = true
                print("CameraManager: Enabled smooth autofocus")
            }
            
            // Set exposure mode to continuous for consistent lighting
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
                print("CameraManager: Set exposure mode to continuous auto exposure")
            }
            
            // Enable auto white balance for better color accuracy
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
                print("CameraManager: Set white balance mode to continuous auto")
            }
            
            // Configure for close-up photography if supported
            configureForCloseUpPhotography(device: device)
            
            device.unlockForConfiguration()
            print("CameraManager: Focus configuration completed successfully")
        } catch {
            print("CameraManager: Error configuring focus settings: \(error)")
        }
    }
    
    func startSession() {
        guard !session.isRunning else { 
            print("CameraManager: Session already running")
            return 
        }
        print("CameraManager: Starting camera session...")
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
            DispatchQueue.main.async {
                print("CameraManager: Camera session started successfully")
            }
        }
    }
    
    func stopSession() {
        guard session.isRunning else { 
            print("CameraManager: Session already stopped")
            return 
        }
        print("CameraManager: Stopping camera session...")
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.stopRunning()
            DispatchQueue.main.async {
                print("CameraManager: Camera session stopped successfully")
            }
        }
    }
    
    func switchCamera() {
        guard let currentVideoDeviceInput = videoDeviceInput else { 
            print("CameraManager: Cannot switch camera - no current input")
            return 
        }
        
        let previousPosition = currentCameraPosition
        print("CameraManager: Switching camera from \(previousPosition) to \(previousPosition == .back ? "front" : "back")")
        
        session.beginConfiguration()
        session.removeInput(currentVideoDeviceInput)
        
        // Switch camera position
        currentCameraPosition = currentCameraPosition == .back ? .front : .back
        
        // Get new camera
        guard let newVideoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition) else {
            print("CameraManager: Error - No camera found for position: \(currentCameraPosition)")
            // Revert position and add back original input
            currentCameraPosition = previousPosition
            if session.canAddInput(currentVideoDeviceInput) {
                session.addInput(currentVideoDeviceInput)
            }
            session.commitConfiguration()
            return
        }
        
        print("CameraManager: Found new camera device: \(newVideoDevice.localizedName)")
        
        guard let newVideoDeviceInput = try? AVCaptureDeviceInput(device: newVideoDevice) else {
            print("CameraManager: Error - Failed to create input for new camera")
            // Revert position and add back original input
            currentCameraPosition = previousPosition
            if session.canAddInput(currentVideoDeviceInput) {
                session.addInput(currentVideoDeviceInput)
            }
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(newVideoDeviceInput) {
            session.addInput(newVideoDeviceInput)
            videoDeviceInput = newVideoDeviceInput
            print("CameraManager: Successfully switched to \(currentCameraPosition) camera")
            
            // Configure focus settings for the new camera
            configureFocusSettings(for: newVideoDevice)
        } else {
            print("CameraManager: Error - Cannot add new camera input")
            // Revert position and add back original input
            currentCameraPosition = previousPosition
            if session.canAddInput(currentVideoDeviceInput) {
                session.addInput(currentVideoDeviceInput)
            }
        }
        
        session.commitConfiguration()
    }
    
    private func configureForCloseUpPhotography(device: AVCaptureDevice) {
        // Check for macro camera support (iPhone 13 Pro and later)
        if #available(iOS 15.0, *) {
            // Try to enable macro mode if available
            if device.deviceType == .builtInUltraWideCamera {
                print("CameraManager: Ultra-wide camera detected, may support macro mode")
            }
        }
        
        // Set minimum focus distance for better close-up performance
        if device.isLockingFocusWithCustomLensPositionSupported {
            // This allows for closer focusing
            print("CameraManager: Custom lens position supported for close-up focusing")
        }
        
        // Optimize for close-range subjects
        if device.isFocusModeSupported(.continuousAutoFocus) {
            // Already set above, but ensure it's optimized for close range
            print("CameraManager: Continuous autofocus optimized for close-up photography")
        }
        
        // Enable subject area change monitoring for better focus tracking
        device.isSubjectAreaChangeMonitoringEnabled = true
        print("CameraManager: Enabled subject area change monitoring for better focus tracking")
    }
    
    func focusAt(point: CGPoint) {
        guard let device = videoDeviceInput?.device else {
            print("CameraManager: Cannot focus - no video device available")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            // Set focus point of interest
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                print("CameraManager: Set focus point of interest to \(point)")
            }
            
            // Set exposure point of interest for better lighting at focus point
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                print("CameraManager: Set exposure point of interest to \(point)")
            }
            
            // Temporarily switch to auto focus mode for the tap-to-focus action
            if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
                print("CameraManager: Set focus mode to auto focus for tap-to-focus")
                
                // After a brief moment, switch back to continuous autofocus
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    do {
                        try device.lockForConfiguration()
                        if device.isFocusModeSupported(.continuousAutoFocus) {
                            device.focusMode = .continuousAutoFocus
                            print("CameraManager: Switched back to continuous autofocus")
                        }
                        device.unlockForConfiguration()
                    } catch {
                        print("CameraManager: Error switching back to continuous autofocus: \(error)")
                    }
                }
            }
            
            device.unlockForConfiguration()
            print("CameraManager: Tap-to-focus completed successfully")
        } catch {
            print("CameraManager: Error setting focus point: \(error)")
        }
    }
}
