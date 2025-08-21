//
//  CameraControlsView.swift
//  EclipseCam
//
//  Created by Jon Mobley on 8/18/25.
//

import SwiftUI
import AVFoundation
import AVKit

struct CameraControlsView: View {
    @ObservedObject var cameraManager: CameraManager
    @StateObject private var settings = SettingsManager.shared
    @State private var showingFocusAnimation = false
    @State private var focusPoint: CGPoint = .zero
    
    // Properties for camera/image toggle
    let hasSelectedMedia: Bool
    let showingCamera: Bool
    let selectedImage: UIImage?
    let onToggleCameraImage: () -> Void
    let onBack: () -> Void
    
    // Orientation mode for layout
    let orientationMode: OrientationMode
    
    var body: some View {
        ZStack {
            // Invisible tap area for focus
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { location in
                    handleTapToFocus(at: location)
                }
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            cameraManager.handlePinchZoom(scale: value, state: .changed)
                        }
                        .onEnded { value in
                            cameraManager.handlePinchZoom(scale: value, state: .ended)
                        }
                )
            
            // Orientation-aware UI Controls
            if orientationMode == .landscape {
                landscapeControlsLayout
            } else {
                portraitControlsLayout
            }
            
            // Focus Animation (same for both orientations)
            if showingFocusAnimation {
                FocusAnimationView(point: focusPoint)
                    .allowsHitTesting(false)
            }
        }
        .alert(cameraManager.alertTitle, isPresented: $cameraManager.showingAlert) {
            Button("OK") { }
        } message: {
            Text(cameraManager.alertMessage)
        }
    }
    
    // MARK: - Landscape Layout (Record button right-center, timer top-center)
    private var landscapeControlsLayout: some View {
        ZStack {
            // Recording Timer - Top Center (only show if recording is enabled)
            if settings.enableRecording {
                VStack {
                    HStack {
                        Spacer()
                        
                        if cameraManager.isRecording {
                            recordingTimerView
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                }
            }
            
            // Top Left Indicators (Zoom)
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        // Zoom Indicator - Only when zoomed
                        if cameraManager.currentZoomScale > 1.0 {
                            zoomIndicatorView
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.top, 50) // Increased padding to account for status bar
                    
                    Spacer()
                }
                
                Spacer()
            }
            
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
            
            // Right Side Button Column (Camera Switch, Record, Media Toggle)
            HStack {
                Spacer()
                
                VStack(spacing: 30) {
                    // Camera Switch Button - Top (or Cancel Recording Button when recording)
                    if cameraManager.isRecording {
                        cancelRecordingButton
                    } else {
                        cameraSwitchButton
                    }
                    
                    // Record Button - Center (only show if recording is enabled)
                    if settings.enableRecording {
                        recordButton
                    } else {
                        // Invisible spacer to maintain layout
                        Color.clear.frame(width: 80, height: 80)
                    }
                    
                    // Media Toggle Button - Bottom
                    mediaToggleButton
                }
                .padding(.trailing, 20)
            }
        }
    }
    
    // MARK: - Portrait Layout (Record button bottom-center, timer top-center)
    private var portraitControlsLayout: some View {
        VStack {
            // Top Controls - Left and Right sides
            HStack {
                // Left side - Exit icon
                HStack {
                    // Exit button
                    exitButton
                }
                
                Spacer()
                
                // Right side - Recording Timer
                if settings.enableRecording && cameraManager.isRecording {
                    recordingTimerView
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 50) // Increased padding to account for status bar
            
            // Zoom Indicator - Below top controls if needed
            if cameraManager.currentZoomScale > 1.0 {
                HStack {
                    zoomIndicatorView
                        .padding(.leading, 20)
                    Spacer()
                }
                .padding(.top, 8)
            }
            
            Spacer()
            
            // Bottom Controls
            HStack {
                // Media Toggle Button - Bottom Left
                mediaToggleButton
                
                Spacer()
                
                // Record Button - Bottom Center (only show if recording is enabled)
                if settings.enableRecording {
                    recordButton
                } else {
                    // Invisible spacer to maintain layout
                    Color.clear.frame(width: 80, height: 80)
                }
                
                Spacer()
                
                // Camera Switch Button - Bottom Right (or Cancel Recording Button when recording)
                if cameraManager.isRecording {
                    cancelRecordingButton
                } else {
                    cameraSwitchButton
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Reusable UI Components
    

    private var exitButton: some View {
        Button(action: {
            // Stop recording if currently recording before returning to main page
            if cameraManager.isRecording {
                cameraManager.stopRecording()
            }
            onBack() // This will take user back to main page
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
    
    private var recordingTimerView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
                .opacity(showingFocusAnimation ? 0.3 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: showingFocusAnimation)
            
            Text(formatRecordingTime(cameraManager.recordingDuration))
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.red)
        .cornerRadius(20)
        .onAppear {
            showingFocusAnimation = true
        }
        .onDisappear {
            showingFocusAnimation = false
        }
    }
    
    private var zoomIndicatorView: some View {
        Text("\(String(format: "%.1f", cameraManager.currentZoomScale))×")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.6))
            .cornerRadius(20)
    }
    
    private var cameraSwitchButton: some View {
        Button(action: {
            if !cameraManager.isRecording {
                cameraManager.switchCamera()
            }
        }) {
            ZStack {
                // White border ring (same as record button)
                Circle()
                    .fill(Color.white)
                    .frame(width: 80, height: 80)
                
                // Dark background circle
                Circle()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: 70, height: 70)
                
                // Camera rotate icon
                Image(systemName: "camera.rotate.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(cameraManager.isRecording)
        .opacity(cameraManager.isRecording ? 0.5 : 1.0)
    }
    
    private var cancelRecordingButton: some View {
        Button(action: {
            cameraManager.cancelRecording()
        }) {
            ZStack {
                // Red border ring to indicate cancel action
                Circle()
                    .fill(Color.red)
                    .frame(width: 80, height: 80)
                
                // Dark background circle
                Circle()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: 70, height: 70)
                
                // X icon
                Image(systemName: "xmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
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
    
    private var mediaToggleButton: some View {
        Group {
            if hasSelectedMedia {
                Button(action: {
                    onToggleCameraImage()
                }) {
                    ZStack {
                        // White border ring (same as other buttons)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 80, height: 80)
                        
                        // Background circle
                        Circle()
                            .fill(Color.black.opacity(0.8))
                            .frame(width: 70, height: 70)
                        
                        if showingCamera {
                            // Show image icon when on camera view (to switch to image)
                            if let image = selectedImage {
                                // Show thumbnail in a circular mask
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } else {
                                // Fallback photo icon
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        } else {
                            // Show camera icon when on image view (to switch to camera)
                            Image(systemName: "video.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                // Invisible spacer to maintain layout when no media selected
                Color.clear
                    .frame(width: 80, height: 80)
            }
        }
    }
    
    private func handleTapToFocus(at location: CGPoint) {
        // Convert SwiftUI coordinate to AVFoundation coordinate (0-1 range)
        let devicePoint = CGPoint(
            x: location.x / UIScreen.main.bounds.width,
            y: location.y / UIScreen.main.bounds.height
        )
        
        cameraManager.focus(at: devicePoint)
        
        // Show focus animation
        focusPoint = location
        showFocusAnimation(at: location)
    }
    
    private func showFocusAnimation(at point: CGPoint) {
        focusPoint = point
        withAnimation(.easeInOut(duration: 0.2)) {
            showingFocusAnimation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingFocusAnimation = false
            }
        }
    }
    
    private func formatRecordingTime(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    

}

struct FocusAnimationView: View {
    let point: CGPoint
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    
    var body: some View {
        Circle()
            .stroke(Color.yellow, lineWidth: 2)
            .frame(width: 80, height: 80)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(point)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.2)) {
                    scale = 1.2
                }
                
                withAnimation(.easeInOut(duration: 0.15).delay(0.2)) {
                    scale = 1.0
                }
                
                withAnimation(.easeInOut(duration: 0.5).delay(0.5)) {
                    opacity = 0
                }
            }
    }
}

#Preview {
    CameraControlsView(
        cameraManager: CameraManager(),
        hasSelectedMedia: true,
        showingCamera: true,
        selectedImage: nil,
        onToggleCameraImage: { },
        onBack: { },
        orientationMode: .landscape
    )
    .background(Color.black)
}
