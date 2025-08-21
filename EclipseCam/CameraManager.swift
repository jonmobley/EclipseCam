//
//  CameraManager.swift
//  EclipseCam
//
//  Created by Jon Mobley on 8/18/25.
//

import AVFoundation
import SwiftUI
import Photos

class CameraManager: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var session = AVCaptureSession()
    
    // Recording properties
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var showingAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    
    // Camera control properties
    @Published var currentZoomScale: CGFloat = 1.0
    
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var recordingTimer: Timer?
    private var shouldDiscardRecording = false
    
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
        } else {
            print("CameraManager: Error - Cannot add video input to session")
        }
        
        // Add audio input for recording
        setupAudioInput()
        
        // Add movie output for recording
        setupMovieOutput()
        
        // Preview layer will be created by CameraPreview UIViewRepresentable
        
        session.commitConfiguration()
        print("CameraManager: Camera setup completed")
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
    
    // MARK: - Recording Setup Methods
    
    private func setupAudioInput() {
        // Remove existing audio input
        if let audioInput = audioDeviceInput {
            session.removeInput(audioInput)
        }
        
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            print("CameraManager: Warning - No audio device found")
            return
        }
        
        guard let audioDeviceInput = try? AVCaptureDeviceInput(device: audioDevice) else {
            print("CameraManager: Error - Failed to create audio device input")
            return
        }
        
        if session.canAddInput(audioDeviceInput) {
            session.addInput(audioDeviceInput)
            self.audioDeviceInput = audioDeviceInput
            print("CameraManager: Successfully added audio input")
        } else {
            print("CameraManager: Error - Cannot add audio input to session")
        }
    }
    
    private func setupMovieOutput() {
        // Remove existing movie output
        if let movieOutput = movieOutput {
            session.removeOutput(movieOutput)
        }
        
        let movieOutput = AVCaptureMovieFileOutput()
        
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            self.movieOutput = movieOutput
            print("CameraManager: Successfully added movie output")
        } else {
            print("CameraManager: Error - Cannot add movie output to session")
        }
    }
    
    // MARK: - Recording Methods
    
    func startRecording() {
        guard let movieOutput = movieOutput else {
            showAlert(title: "Recording Error", message: "Movie output not available")
            return
        }
        
        guard !isRecording else {
            print("CameraManager: Already recording")
            return
        }
        
        // Create output file URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).mov")
        
        // Reset recording state
        shouldDiscardRecording = false
        recordingDuration = 0
        
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        
        DispatchQueue.main.async {
            self.isRecording = true
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
    
    func cancelRecording() {
        guard isRecording else { return }
        
        print("CameraManager: Canceling recording (will not save)")
        
        // Set flag to indicate this recording should be discarded
        shouldDiscardRecording = true
        
        movieOutput?.stopRecording()
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.stopRecordingTimer()
        }
        
        print("CameraManager: Recording canceled")
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.recordingDuration += 1
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    // MARK: - Camera Control Methods
    
    func handlePinchZoom(scale: CGFloat, state: UIGestureRecognizer.State) {
        guard let device = videoDeviceInput?.device else { return }
        
        switch state {
        case .changed:
            let newZoomScale = min(max(currentZoomScale * scale, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            zoom(to: newZoomScale)
        case .ended:
            // Zoom gesture ended, keep current zoom
            break
        default:
            break
        }
    }
    
    func zoom(to scale: CGFloat) {
        guard let device = videoDeviceInput?.device else { return }
        
        let clampedScale = min(max(scale, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedScale
            device.unlockForConfiguration()
            
            DispatchQueue.main.async {
                self.currentZoomScale = clampedScale
            }
        } catch {
            print("CameraManager: Failed to set zoom: \(error)")
        }
    }
    
    func focus(at point: CGPoint) {
        guard let device = videoDeviceInput?.device else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
            print("CameraManager: Focus set to point: \(point)")
        } catch {
            print("CameraManager: Failed to set focus: \(error)")
        }
    }
    
    // MARK: - Alert Helper
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("CameraManager: Recording started to file: \(fileURL.path)")
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print("CameraManager: Recording finished to file: \(outputFileURL.path)")
        
        if let error = error {
            print("CameraManager: Recording error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.showAlert(title: "Recording Error", message: error.localizedDescription)
            }
            return
        }
        
        // Check if recording should be discarded
        if shouldDiscardRecording {
            print("CameraManager: Discarding recording as requested")
            try? FileManager.default.removeItem(at: outputFileURL)
            return
        }
        
        // Save to photo library
        saveVideoToPhotoLibrary(url: outputFileURL)
    }
    
    private func saveVideoToPhotoLibrary(url: URL) {
        // Check photo library permission
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized, .limited:
            performSave(url: url)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                if status == .authorized || status == .limited {
                    self?.performSave(url: url)
                } else {
                    DispatchQueue.main.async {
                        self?.showAlert(title: "Save Failed", message: "Photo library access denied")
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.showAlert(title: "Save Failed", message: "Photo library access denied")
            }
        @unknown default:
            DispatchQueue.main.async {
                self.showAlert(title: "Save Failed", message: "Unknown photo library permission status")
            }
        }
    }
    
    private func performSave(url: URL) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    print("CameraManager: Video saved to photo library successfully")
                    self?.showAlert(title: "Recording Saved", message: "Video saved to photo library")
                } else if let error = error {
                    print("CameraManager: Failed to save video: \(error.localizedDescription)")
                    self?.showAlert(title: "Save Failed", message: error.localizedDescription)
                }
            }
            
            // Clean up temporary file
            try? FileManager.default.removeItem(at: url)
        }
    }
}
