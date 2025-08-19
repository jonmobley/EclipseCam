//
//  CameraPreview.swift
//  EclipseCam
//
//  Created by Jon Mobley on 8/18/25.
//

import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let orientationMode: OrientationMode
    let onTapToFocus: ((CGPoint) -> Void)?
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = UIColor.black
        view.session = session
        view.orientationMode = orientationMode
        view.onTapToFocus = onTapToFocus
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        uiView.session = session
        uiView.orientationMode = orientationMode
        uiView.onTapToFocus = onTapToFocus
    }
}

class VideoPreviewView: UIView {
    private var retryCount = 0
    private let maxRetries = 50 // Maximum number of retries
    var onTapToFocus: ((CGPoint) -> Void)?
    
    var session: AVCaptureSession? {
        didSet {
            guard let session = session else { return }
            videoPreviewLayer.session = session
            retryCount = 0 // Reset retry count when session changes
            // Wait a bit longer for the session to be fully configured
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.updateVideoOrientation()
            }
        }
    }
    
    var orientationMode: OrientationMode = .portrait {
        didSet {
            updateVideoOrientation()
        }
    }
    
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTapGesture()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTapGesture()
    }
    
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let tapPoint = gesture.location(in: self)
        
        // Convert tap point to camera coordinate system (0,0 to 1,1)
        let focusPoint = CGPoint(
            x: tapPoint.x / bounds.width,
            y: tapPoint.y / bounds.height
        )
        
        print("CameraPreview: Tap detected at \(tapPoint), converted to focus point \(focusPoint)")
        onTapToFocus?(focusPoint)
        
        // Show visual feedback for the tap
        showFocusIndicator(at: tapPoint)
    }
    
    private func showFocusIndicator(at point: CGPoint) {
        // Remove any existing focus indicator
        subviews.filter { $0.tag == 999 }.forEach { $0.removeFromSuperview() }
        
        // Create focus indicator
        let focusView = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        focusView.center = point
        focusView.backgroundColor = UIColor.clear
        focusView.layer.borderColor = UIColor.yellow.cgColor
        focusView.layer.borderWidth = 2
        focusView.layer.cornerRadius = 40
        focusView.tag = 999
        focusView.alpha = 0
        
        addSubview(focusView)
        
        // Animate the focus indicator
        UIView.animate(withDuration: 0.2, animations: {
            focusView.alpha = 1
            focusView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0.5, animations: {
                focusView.alpha = 0
                focusView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            }) { _ in
                focusView.removeFromSuperview()
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateVideoOrientation()
    }
    
    private func updateVideoOrientation() {
        // Check if session is running first
        guard let session = session, session.isRunning else {
            retryCount += 1
            if retryCount <= maxRetries {
                print("CameraPreview: Session not running - retry \(retryCount)/\(maxRetries)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.updateVideoOrientation()
                }
            } else {
                print("CameraPreview: Max retries reached, session not running")
            }
            return
        }
        
        guard let connection = videoPreviewLayer.connection else {
            retryCount += 1
            if retryCount <= maxRetries {
                print("CameraPreview: No video connection available - retry \(retryCount)/\(maxRetries)")
                // Retry after a short delay if connection isn't ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.updateVideoOrientation()
                }
            } else {
                print("CameraPreview: Max retries reached, giving up on video connection")
            }
            return
        }
        
        print("CameraPreview: Video connection established after \(retryCount) retries")
        
        // Use modern iOS 17+ API when available, fallback to legacy for older versions
        if #available(iOS 17.0, *) {
            // Modern approach using rotation angles
            let rotationAngle: CGFloat
            switch orientationMode {
            case .portrait:
                rotationAngle = 90.0  // 90 degrees to rotate landscape camera to portrait
            case .landscape:
                rotationAngle = 0.0   // 0 degrees for landscape (natural camera orientation)
            }
            
            if connection.isVideoRotationAngleSupported(rotationAngle) {
                connection.videoRotationAngle = rotationAngle
                print("CameraPreview: Set video rotation angle to \(rotationAngle)° for \(orientationMode)")
            } else {
                print("CameraPreview: Video rotation angle \(rotationAngle)° not supported")
            }
        } else {
            // Legacy approach for iOS 16 and earlier
            guard connection.isVideoOrientationSupported else {
                print("CameraPreview: Video orientation not supported")
                return
            }
            
            let newOrientation: AVCaptureVideoOrientation
            switch orientationMode {
            case .portrait:
                newOrientation = .portrait
            case .landscape:
                newOrientation = .landscapeRight
            }
            
            connection.videoOrientation = newOrientation
            print("CameraPreview: Set video orientation to \(newOrientation) for \(orientationMode)")
        }
        
        // Always fill the screen
        videoPreviewLayer.videoGravity = .resizeAspectFill
        print("CameraPreview: Video gravity set to resizeAspectFill")
    }
}
