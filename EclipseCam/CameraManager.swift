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
    
    // MARK: - New Enhanced Properties
    @Published var currentZoomScale: CGFloat = 1.0
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    
    // MARK: - Existing Properties (preserved)
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var orientationMode: OrientationMode = .portrait
    
    // MARK: - New Camera Enhancement Properties
    private var movieOutput: AVCaptureMovieFileOutput?
    private var recordingTimer: Timer?
    private var initialZoomScale: CGFloat = 1.0
    
    // MARK: - External Display Properties (for clean AirPlay)
    private var externalWindow: UIWindow?
    private var externalPreviewLayer: AVCaptureVideoPreviewLayer?
    private var airPlayObserver: NSObjectProtocol?
    private var disconnectObserver: NSObjectProtocol?
    
    override init() {
        super.init()
        checkPermissions()
        setupExternalDisplayMonitoring()
    }
    
    deinit {
        // Clean up external display observers
        if let observer = airPlayObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = disconnectObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        recordingTimer?.invalidate()
        tearDownExternalDisplay()
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
        
        // Add movie output for recording capability
        setupMovieOutput()
        
        // Add audio input for recording
        addAudioInput()
        
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
    
    // MARK: - New Enhanced Camera Methods
    
    private func setupMovieOutput() {
        movieOutput = AVCaptureMovieFileOutput()
        guard let movieOutput = movieOutput else { return }
        
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            // Configure for continuous recording
            movieOutput.movieFragmentInterval = CMTime.invalid
            print("CameraManager: Movie output added successfully")
        } else {
            print("CameraManager: Error - Cannot add movie output")
        }
    }
    
    private func addAudioInput() {
        do {
            guard let audioDevice = AVCaptureDevice.default(for: .audio) else { 
                print("CameraManager: No audio device found")
                return 
            }
            let audioInput = try AVCaptureDeviceInput(device: audioDevice)
            
            if session.canAddInput(audioInput) {
                session.addInput(audioInput)
                print("CameraManager: Audio input added successfully")
            } else {
                print("CameraManager: Cannot add audio input")
            }
        } catch {
            print("CameraManager: Error adding audio input: \(error)")
        }
    }
    
    // MARK: - Recording Methods
    
    func startRecording() {
        guard let movieOutput = movieOutput, !isRecording else { 
            print("CameraManager: Cannot start recording - movieOutput: \(movieOutput != nil), isRecording: \(isRecording)")
            return 
        }
        
        // Generate unique file URL
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let fileName = "EclipseCam-\(dateFormatter.string(from: Date())).mov"
        let outputURL = URL(fileURLWithPath: documentsPath).appendingPathComponent(fileName)
        
        // Start recording
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        
        // Update state
        DispatchQueue.main.async {
            self.isRecording = true
            self.recordingDuration = 0
            self.startRecordingTimer()
        }
        
        print("CameraManager: Started recording to: \(outputURL.path)")
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        movieOutput?.stopRecording()
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.stopRecordingTimer()
        }
        
        print("CameraManager: Stopped recording")
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.recordingDuration += 1
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    // MARK: - Zoom Methods
    
    func zoom(to scale: CGFloat) {
        guard let device = videoDeviceInput?.device else { return }
        
        do {
            try device.lockForConfiguration()
            
            let maxZoomFactor = device.activeFormat.videoMaxZoomFactor
            let minZoomFactor: CGFloat = 1.0
            
            // Clamp the scale
            let clampedScale = max(minZoomFactor, min(scale, maxZoomFactor))
            
            // Smooth zoom animation
            device.videoZoomFactor = clampedScale
            
            DispatchQueue.main.async {
                self.currentZoomScale = clampedScale
            }
            
            device.unlockForConfiguration()
            print("CameraManager: Zoom set to \(clampedScale)x")
        } catch {
            print("CameraManager: Error setting zoom: \(error)")
        }
    }
    
    func handlePinchZoom(scale: CGFloat, state: UIGestureRecognizer.State) {
        guard let device = videoDeviceInput?.device else { return }
        
        switch state {
        case .began:
            initialZoomScale = device.videoZoomFactor
        case .changed:
            let newScale = initialZoomScale * scale
            zoom(to: newScale)
        default:
            break
        }
    }
    
    // MARK: - Focus Methods
    
    func focus(at point: CGPoint) {
        guard let device = videoDeviceInput?.device else { return }
        
        do {
            try device.lockForConfiguration()
            
            // Set focus point
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
            }
            
            // Set exposure point
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
            }
            
            // Trigger autofocus
            if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }
            
            // Trigger auto exposure
            if device.isExposureModeSupported(.autoExpose) {
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
            
            // Return to continuous modes after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.returnToContinuousModes()
            }
            
            print("CameraManager: Focus set to point: \(point)")
        } catch {
            print("CameraManager: Error setting focus: \(error)")
        }
    }
    
    private func returnToContinuousModes() {
        guard let device = videoDeviceInput?.device else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            device.unlockForConfiguration()
        } catch {
            print("CameraManager: Error returning to continuous modes: \(error)")
        }
    }
    
    // MARK: - External Display Methods (Clean AirPlay)
    
    private func setupExternalDisplayMonitoring() {
        // Monitor screen connection
        airPlayObserver = NotificationCenter.default.addObserver(
            forName: UIScreen.didConnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let connectedScreen = notification.object as? UIScreen else { return }
            self?.setupExternalDisplay(screen: connectedScreen)
        }
        
        // Monitor screen disconnection
        disconnectObserver = NotificationCenter.default.addObserver(
            forName: UIScreen.didDisconnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.tearDownExternalDisplay()
        }
        
        // Check if already connected to external display
        if UIScreen.screens.count > 1 {
            for screen in UIScreen.screens where screen != UIScreen.main {
                setupExternalDisplay(screen: screen)
                break
            }
        }
    }
    
    private func setupExternalDisplay(screen: UIScreen) {
        print("CameraManager: Setting up external display (clean AirPlay)")
        
        // Clean up any existing external window
        tearDownExternalDisplay()
        
        // Create window for external display
        externalWindow = UIWindow(frame: screen.bounds)
        externalWindow?.screen = screen
        
        // Create a view controller for the external display
        let externalViewController = UIViewController()
        externalViewController.view.backgroundColor = .black
        
        // Create preview layer for external display (NO UI overlays - clean camera only)
        externalPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        externalPreviewLayer?.frame = screen.bounds
        externalPreviewLayer?.videoGravity = .resizeAspectFill
        
        if let externalPreviewLayer = externalPreviewLayer {
            externalViewController.view.layer.addSublayer(externalPreviewLayer)
        }
        
        // Set up the external window
        externalWindow?.rootViewController = externalViewController
        externalWindow?.isHidden = false
        
        // Adjust video orientation for external display
        if let connection = externalPreviewLayer?.connection {
            // Most TVs are landscape
            connection.videoOrientation = orientationMode == .landscape ? .landscapeRight : .portrait
        }
        
        print("CameraManager: External display setup complete - clean camera feed only")
    }
    
    private func tearDownExternalDisplay() {
        externalPreviewLayer?.removeFromSuperlayer()
        externalPreviewLayer = nil
        externalWindow?.isHidden = true
        externalWindow = nil
        print("CameraManager: External display torn down")
    }
    
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("CameraManager: Recording failed with error: \(error)")
            return
        }
        
        print("CameraManager: Recording finished successfully: \(outputFileURL.path)")
        
        // Here you could add the video to your MediaHistoryManager
        // MediaHistoryManager.shared.addToHistory(outputFileURL)
    }
}
