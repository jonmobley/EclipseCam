//
//  ContentView.swift
//  EclipseCam
//
//  Created by Jon Mobley on 8/18/25.
//
//  TESTING CHECKLIST:
//  1. Launch app - should show main menu in portrait
//  2. Tap "Go Live" - should show orientation dialog
//  3. Select "Portrait Mode" - should rotate to portrait and show camera
//  4. Select "Landscape Mode" - should rotate to landscape and show camera
//  5. Tap camera rotate button - should switch front/back cameras
//  6. Tap back button - should return to main menu in portrait
//  7. Check console for debug messages during each step
//

import SwiftUI
import AVFoundation
import AVKit
import PhotosUI
import UIKit

enum OrientationMode: CaseIterable {
    case portrait // 9:16
    case landscape // 16:9
    
    var displayName: String {
        switch self {
        case .portrait: return "Portrait Mode (9:16)"
        case .landscape: return "Landscape Mode (16:9)"
        }
    }
    
    var preferredOrientation: UIInterfaceOrientation {
        switch self {
        case .portrait: return .portrait
        case .landscape: return .landscapeRight
        }
    }
}

struct ContentView: View {
    @State private var selectedMode: OrientationMode = .landscape // Default to Horizontal
    @State private var showCameraView = false
    @State private var showFullscreenImage = false
    @State private var preSelectedImage: UIImage?
    @State private var showingMainImagePicker = false
    
    // Force main menu to always display in portrait
    init() {
        // Force portrait orientation for main menu on app launch
        OrientationManager.shared.setOrientation(UIInterfaceOrientation.portrait)
    }
    
    var body: some View {
        NavigationView {
            if showFullscreenImage, let image = preSelectedImage {
                FullscreenImageView(image: image, onDismiss: {
                    showFullscreenImage = false
                    showCameraView = true
                }, onBack: {
                    // Back to main menu
                    showFullscreenImage = false
                    OrientationManager.shared.setOrientation(UIInterfaceOrientation.portrait)
                })
                .preferredColorScheme(.dark)
            } else if showCameraView {
                CameraView(orientationMode: selectedMode, preSelectedImage: preSelectedImage) {
                    // Back button callback  
                    showCameraView = false
                    // Set back to portrait for main menu
                    OrientationManager.shared.setOrientation(UIInterfaceOrientation.portrait)
                }
                .preferredColorScheme(.dark)
            } else {
                MainMenuView(
                    selectedMode: $selectedMode,
                    preSelectedImage: $preSelectedImage, 
                    showingImagePicker: $showingMainImagePicker
                ) {
                    // Go Live action
                    OrientationManager.shared.setOrientation(selectedMode.preferredOrientation)
                    // Small delay to ensure orientation change takes effect
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if preSelectedImage != nil {
                            showFullscreenImage = true
                        } else {
                            showCameraView = true
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .navigationViewStyle(StackNavigationViewStyle())
        .homeIndicatorHidden(showCameraView || showFullscreenImage)
        .sheet(isPresented: $showingMainImagePicker) {
            EnhancedImagePicker(
                selectedImage: $preSelectedImage,
                onImageSelected: { image, isFromHistory in
                    // Only add to history if it's from camera roll, not from history
                    if !isFromHistory {
                        MediaHistoryManager.shared.addToHistory(image)
                    }
                }
            )
        }
    }
}

struct MainMenuView: View {
    @Binding var selectedMode: OrientationMode
    @Binding var preSelectedImage: UIImage?
    @Binding var showingImagePicker: Bool
    let onGoLive: () -> Void
    
    var body: some View {
        ZStack {
            // Black background for clean AirPlay appearance
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Spacer for top padding
                Spacer()
                    .frame(height: 60) // Safe area padding for top
                
                VStack(spacing: 20) {
                    // Orientation Toggle
                    HStack(spacing: 0) {
                        // Horizontal tab
                        Button(action: {
                            selectedMode = .landscape
                        }) {
                            Text("Horizontal")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(selectedMode == .landscape ? .black : .white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(selectedMode == .landscape ? .white : Color.clear)
                        }
                        .buttonStyle(.plain)
                        
                        // Vertical tab
                        Button(action: {
                            selectedMode = .portrait
                        }) {
                            Text("Vertical")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(selectedMode == .portrait ? .black : .white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(selectedMode == .portrait ? .white : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                    
                    // Dynamic Aspect Ratio Image Selection Area
                    VStack(spacing: 12) {
                        if let image = preSelectedImage {
                            // Show selected image thumbnail - tappable to change
                            Button(action: {
                                showingImagePicker = true
                            }) {
                                GeometryReader { geometry in
                                    HStack {
                                        if selectedMode == .portrait {
                                            Spacer() // Center the vertical thumbnail
                                        }
                                        
                                        ZStack {
                                            // Image background with dynamic aspect ratio
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(
                                                    width: selectedMode == .landscape ? geometry.size.width : 180 * 9/16,
                                                    height: geometry.size.width * 9/16
                                                )
                                                .clipped()
                                                .cornerRadius(10)
                                                .id("\(selectedMode)") // Force refresh when orientation changes
                                        
                                        // Overlay with delete option in bottom-right corner
                                        VStack {
                                            Spacer()
                                            HStack {
                                                Spacer()
                                                // Trash can button in bottom-right corner
                                                Button(action: {
                                                    preSelectedImage = nil
                                                }) {
                                                                                                    Image(systemName: "trash.circle.fill")
                                                    .font(.system(size: 36, weight: .medium))
                                                    .foregroundColor(.white)
                                                    .background(Color.red.opacity(0.8))
                                                    .clipShape(Circle())
                                                }
                                                .buttonStyle(.plain)
                                                .padding(.bottom, 8)
                                                .padding(.trailing, 8)
                                            }
                                        }
                                        .frame(
                                            width: selectedMode == .landscape ? geometry.size.width : 180 * 9/16,
                                            height: geometry.size.width * 9/16
                                        )
                                        }
                                        
                                        if selectedMode == .portrait {
                                            Spacer() // Center the vertical thumbnail
                                        }
                                    }
                                }
                                .frame(height: nil) // Let content determine height
                                .contentShape(Rectangle()) // Define precise hit area
                            }
                            .buttonStyle(.plain)
                        } else {
                            // Show dashed placeholder area
                            Button(action: {
                                showingImagePicker = true
                            }) {
                                GeometryReader { geometry in
                                    HStack {
                                        if selectedMode == .portrait {
                                            Spacer() // Center the vertical thumbnail
                                        }
                                        
                                        ZStack {
                                            // Dashed border background - full tappable area
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(
                                                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                                                )
                                                .foregroundColor(.white.opacity(0.4))
                                                .frame(
                                                    width: selectedMode == .landscape ? geometry.size.width : 180 * 9/16,
                                                    height: geometry.size.width * 9/16
                                                )
                                            
                                            // Invisible tappable area covering entire thumbnail
                                            Color.clear
                                                .frame(
                                                    width: selectedMode == .landscape ? geometry.size.width : 180 * 9/16,
                                                    height: geometry.size.width * 9/16
                                                )
                                                .contentShape(Rectangle())
                                            
                                            // Centered content (visual only)
                                            Image(systemName: "photo")
                                                .font(.system(size: 40, weight: .light))
                                                .foregroundColor(.white.opacity(0.6))
                                                .allowsHitTesting(false) // Prevent icon from intercepting taps
                                        }
                                        
                                        if selectedMode == .portrait {
                                            Spacer() // Center the vertical thumbnail
                                        }
                                    }
                                }
                                .frame(height: nil) // Let content determine height
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Settings section
                    SettingsView()
                        .padding(.horizontal, 20)
                        .padding(.top, 40) // Increased spacing from thumbnail
                    
                    Spacer() // Push buttons to bottom
                    
                    // Go Live button
                    Button(action: {
                        onGoLive()
                    }) {
                        Text("Go Live")
                            .fontWeight(.semibold)
                            .font(.system(size: 17)) // Standard button font size
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50) // Standard touch target height
                            .background(Color.accentColor) // Use system accent color
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain) // Use standard button interaction
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20) // Reduced padding - closer to bottom
                }
                .padding(.bottom, 20) // Reduced padding - closer to bottom
            }
        }
        .statusBarHidden(false) // Ensure status bar is visible on main menu
    }
}


struct CameraView: View {
    let orientationMode: OrientationMode
    let preSelectedImage: UIImage?
    let onBack: () -> Void
    
    @StateObject private var cameraManager = CameraManager()
    @State private var selectedImage: UIImage?
    @State private var selectedVideoURL: URL?
    @State private var selectedMediaItem: MediaHistoryItem?
    @State private var showingImagePicker = false
    @State private var showingFullscreenImage = false
    @State private var showingCamera = true // Track whether to show camera or image
    
    var body: some View {
        ZStack {
            // Black background for clean AirPlay appearance
            Color.black.ignoresSafeArea()
            
            // Main content - showing either camera or media
            if showingCamera {
                // CAMERA VIEW
                if cameraManager.isAuthorized {
                    ZStack {
                        // Live camera preview
                        CameraPreview(
                            session: cameraManager.session, 
                            orientationMode: orientationMode
                        )
                        .ignoresSafeArea()
                        
                        // Camera controls overlay
                        CameraControlsView(
                            cameraManager: cameraManager,
                            hasSelectedMedia: selectedImage != nil || selectedVideoURL != nil,
                            showingCamera: showingCamera,
                            selectedImage: selectedImage,
                            onToggleCameraImage: {
                                print("🎬 Toggle from camera to media")
                                // Stop recording if currently recording when switching to image mode
                                if cameraManager.isRecording {
                                    cameraManager.stopRecording()
                                }
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showingCamera = false
                                }
                            },
                            onBack: onBack,
                            orientationMode: orientationMode
                        )
                        .ignoresSafeArea()
                    }
                } else {
                    // Permission denied or not granted
                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("Camera Access Required")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Please enable camera access in Settings to use live video")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
            } else {
                // MEDIA VIEW (Image or Video)
                ZStack {
                    // Show the media content
                    if let videoURL = selectedVideoURL {
                        // Show selected video with seamless looping
                        SeamlessVideoPlayer(videoURL: videoURL, aspectFit: false)
                            .ignoresSafeArea()
                    } else if let image = selectedImage {
                        // Show selected image
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .ignoresSafeArea()
                            .clipped()
                    }
                    
                    // Simple toggle button overlay - ALWAYS show when not in camera mode
                    SimpleCameraToggleButton(
                        orientationMode: orientationMode,
                        isRecording: cameraManager.isRecording,
                        onToggle: {
                            print("🎬 Toggle from media back to camera")
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingCamera = true
                            }
                        }
                    )
                }
            }
            .onLongPressGesture(minimumDuration: 1.0) {
                // Long press: Return to main menu
                // Stop recording if currently recording before returning to main page
                if cameraManager.isRecording {
                    cameraManager.stopRecording()
                }
                onBack()
            }
            .gesture(
                // Swipe up from bottom edge: Return to main menu
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        // Check if swipe started from bottom edge and moved up
                        let screenHeight = UIScreen.main.bounds.height
                        let startY = value.startLocation.y
                        let endY = value.location.y
                        let swipeDistance = startY - endY
                        
                        // Swipe must start from bottom 100 points of screen and move up at least 50 points
                        if startY > screenHeight - 100 && swipeDistance > 50 {
                            // Stop recording if currently recording before returning to main page
                            if cameraManager.isRecording {
                                cameraManager.stopRecording()
                            }
                            onBack()
                        }
                    }
            )
        }
        .localCameraMode()
        .onAppear {
            // Initialize with pre-selected image if available
            if selectedImage == nil {
                selectedImage = preSelectedImage
                // If we have a pre-selected image, start in media mode
                if preSelectedImage != nil {
                    showingCamera = false
                }
            }
            
            cameraManager.configure(for: orientationMode)
            // Small delay to ensure configuration is complete before starting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                cameraManager.startSession()
                
                // Auto-start recording if enabled and showing camera
                if showingCamera && SettingsManager.shared.automaticallyRecord && SettingsManager.shared.enableRecording {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        cameraManager.startRecording()
                    }
                }
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .sheet(isPresented: $showingImagePicker) {
            EnhancedImagePicker(
                selectedImage: $selectedImage,
                selectedVideoURL: $selectedVideoURL,
                onImageSelected: { image, isFromHistory in
                    print("🎬 CameraView: onImageSelected called with image, isFromHistory=\(isFromHistory)")
                    
                    // Clear video selection when image is selected
                    selectedVideoURL = nil
                    selectedMediaItem = nil
                    showingCamera = false // Switch to media view
                    
                    // Only add to history if it's from camera roll, not from history
                    if !isFromHistory {
                        MediaHistoryManager.shared.addToHistory(image)
                    }
                },
                onVideoSelected: { videoURL, isFromHistory in
                    print("🎬 CameraView: onVideoSelected called with: \(videoURL.absoluteString)")
                    
                    // Clear image selection when video is selected
                    selectedImage = nil
                    selectedMediaItem = nil
                    showingCamera = false // Switch to media view
                    
                    selectedVideoURL = videoURL
                }
            )
        }
        .fullScreenCover(isPresented: $showingFullscreenImage) {
            Group {
                if let videoURL = selectedVideoURL {
                    FullscreenVideoView(videoURL: videoURL, onDismiss: {
                        showingFullscreenImage = false
                    }, onBack: onBack)
                } else if let image = selectedImage {
                    FullscreenMediaView(image: image, onDismiss: {
                        showingFullscreenImage = false
                    }, onBack: onBack)
                }
            }
        }
    }
}

// MARK: - Media Picker
struct MediaPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var selectedVideoURL: URL?
    @Environment(\.dismiss) private var dismiss
    
    var onVideoSelected: ((URL) -> Void)? = nil
    var onImageSelected: ((UIImage) -> Void)? = nil
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        picker.mediaTypes = ["public.image", "public.movie"] // Support both images and videos
        picker.videoQuality = .typeHigh
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: MediaPicker
        
        init(_ parent: MediaPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            print("🎬 MediaPicker: Media selected, info keys: \(info.keys)")
            
            // Check media type first
            if let mediaType = info[.mediaType] as? String {
                print("🎬 MediaPicker: Media type: \(mediaType)")
                
                if mediaType == "public.movie", let videoURL = info[.mediaURL] as? URL {
                    print("🎬 MediaPicker: Video selected: \(videoURL.absoluteString)")
                    print("🎬 MediaPicker: This is a temporary file, copying immediately...")
                    
                    // Copy the temporary file to a more permanent location immediately
                    do {
                        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let tempDirectory = documentsPath.appendingPathComponent("TempVideos")
                        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
                        
                        let tempFileName = "temp_\(UUID().uuidString).mov"
                        let tempDestination = tempDirectory.appendingPathComponent(tempFileName)
                        
                        try FileManager.default.copyItem(at: videoURL, to: tempDestination)
                        print("🎬 MediaPicker: Video copied to temp location: \(tempDestination.path)")
                        
                        // Use completion handler instead of binding
                        DispatchQueue.main.async {
                            print("🎬 MediaPicker: Calling onVideoSelected with: \(tempDestination.absoluteString)")
                            self.parent.onVideoSelected?(tempDestination)
                            print("🎬 MediaPicker: onVideoSelected called")
                        }
                    } catch {
                        print("🎬 MediaPicker: Failed to copy temp video: \(error)")
                        // Fallback to original URL (might not work)
                        DispatchQueue.main.async {
                            self.parent.selectedVideoURL = videoURL
                            self.parent.selectedImage = nil
                        }
                    }
                }
                // Check if it's an image
                else if mediaType == "public.image", let image = info[.originalImage] as? UIImage {
                    print("🎬 MediaPicker: Image selected")
                    parent.onImageSelected?(image)
                }
                else {
                    print("🎬 MediaPicker: Unsupported media type: \(mediaType)")
                }
            }
            else {
                print("🎬 MediaPicker: No media type found in info")
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Legacy Image Picker (for backward compatibility)
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Seamless Video Player
struct SeamlessVideoPlayer: UIViewRepresentable {
    let videoURL: URL
    let aspectFit: Bool
    
    init(videoURL: URL, aspectFit: Bool = true) {
        self.videoURL = videoURL
        self.aspectFit = aspectFit
    }
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.clear
        
        // Create AVPlayer
        let player = AVPlayer(url: videoURL)
        let playerLayer = AVPlayerLayer(player: player)
        
        // Configure player layer
        playerLayer.videoGravity = aspectFit ? .resizeAspect : .resizeAspectFill
        playerLayer.frame = containerView.bounds
        containerView.layer.addSublayer(playerLayer)
        
        // Store player and layer for coordinator
        context.coordinator.player = player
        context.coordinator.playerLayer = playerLayer
        
        // Configure for seamless looping
        player.actionAtItemEnd = .none
        
        // Add notification for looping
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(context.coordinator.playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
        
        // Start playing
        player.play()
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update player layer frame when view size changes
        context.coordinator.playerLayer?.frame = uiView.bounds
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        var player: AVPlayer?
        var playerLayer: AVPlayerLayer?
        
        @objc func playerDidFinishPlaying() {
            // Seamlessly loop the video
            player?.seek(to: CMTime.zero)
            player?.play()
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
            player?.pause()
        }
    }
}

// MARK: - Fullscreen Media View
struct FullscreenMediaView: View {
    let mediaItem: MediaHistoryItem?
    let image: UIImage?
    let videoURL: URL?
    let onDismiss: () -> Void
    let onBack: () -> Void
    
    // Initialize with MediaHistoryItem
    init(mediaItem: MediaHistoryItem, onDismiss: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.mediaItem = mediaItem
        self.image = mediaItem.image
        self.videoURL = mediaItem.videoURL
        self.onDismiss = onDismiss
        self.onBack = onBack
    }
    
    // Initialize with UIImage (backward compatibility)
    init(image: UIImage, onDismiss: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.mediaItem = nil
        self.image = image
        self.videoURL = nil
        self.onDismiss = onDismiss
        self.onBack = onBack
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let videoURL = videoURL {
                // Video playback
                SeamlessVideoPlayer(videoURL: videoURL, aspectFit: true)
                    .ignoresSafeArea()
            } else if let image = image {
                // Image display
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .ignoresSafeArea()
            }
            
            // Controls overlay
            VStack {
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                            Text("Back")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                Spacer()
            }
        }
        .fullscreenMode()
    }
}

// MARK: - Fullscreen Video View
struct FullscreenVideoView: View {
    let videoURL: URL
    let onDismiss: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Video playback
            SeamlessVideoPlayer(videoURL: videoURL, aspectFit: true)
                .ignoresSafeArea()
            
            // Controls overlay
            VStack {
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                            Text("Back")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                Spacer()
            }
        }
        .fullscreenMode()
    }
}

// MARK: - Fullscreen Image View (Legacy - for backward compatibility)
struct FullscreenImageView: View {
    let image: UIImage
    let onDismiss: () -> Void
    let onBack: () -> Void
    
    init(image: UIImage, onDismiss: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.image = image
        self.onDismiss = onDismiss
        self.onBack = onBack
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .clipped()
            
            // Invisible interaction layer
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(count: 1) {
                    // Single tap: Dismiss
                    onDismiss()
                }
                .onLongPressGesture(minimumDuration: 1.0) {
                    // Long press: Return to main menu
                    onBack()
                }
                .gesture(
                    // Swipe up from bottom edge: Return to main menu
                    DragGesture(minimumDistance: 50)
                        .onEnded { value in
                            // Check if swipe started from bottom edge and moved up
                            let screenHeight = UIScreen.main.bounds.height
                            let startY = value.startLocation.y
                            let endY = value.location.y
                            let swipeDistance = startY - endY
                            
                            // Swipe must start from bottom 100 points of screen and move up at least 50 points
                            if startY > screenHeight - 100 && swipeDistance > 50 {
                                onBack()
                            }
                        }
                )
        }
        .fullscreenMode()
    }
}

// MARK: - Debug Route Picker
class DebugRoutePickerView: AVRoutePickerView {
    private weak var backgroundButton: UIButton?
    
    func setBackgroundButton(_ button: UIButton) {
        self.backgroundButton = button
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("🎵 AirPlay: 👆 TouchesBegan on RoutePickerView - frame: \(self.frame), bounds: \(self.bounds)")
        print("🎵 AirPlay: 👆 Touch location: \(touches.first?.location(in: self) ?? CGPoint.zero)")
        
        // Add visual feedback - darken the button
        if let button = backgroundButton {
            UIView.animate(withDuration: 0.1) {
                button.alpha = 0.7
            }
        }
        
        super.touchesBegan(touches, with: event)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("🎵 AirPlay: 👆 TouchesEnded on RoutePickerView")
        
        // Restore normal appearance
        if let button = backgroundButton {
            UIView.animate(withDuration: 0.2) {
                button.alpha = 1.0
            }
        }
        
        super.touchesEnded(touches, with: event)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("🎵 AirPlay: 👆 TouchesCancelled on RoutePickerView")
        
        // Restore normal appearance
        if let button = backgroundButton {
            UIView.animate(withDuration: 0.2) {
                button.alpha = 1.0
            }
        }
        
        super.touchesCancelled(touches, with: event)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        print("🎵 AirPlay: 🎯 HitTest at point: \(point), result: \(result != nil ? "✅ Hit" : "❌ Miss")")
        return result
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let inside = super.point(inside: point, with: event)
        print("🎵 AirPlay: 📍 Point inside: \(point), result: \(inside ? "✅ Inside" : "❌ Outside")")
        return inside
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section Header - Apple HIG Typography
            HStack {
                Text("Settings")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            // Settings Groups with Apple HIG spacing
            VStack(spacing: 0) {
                // Recording Settings Group
                VStack(spacing: 0) {
                    SettingToggleRow(
                        title: "Recording",
                        isOn: $settings.enableRecording,
                        action: { enabled in
                            settings.updateEnableRecording(enabled)
                        }
                    )
                    
                    // Apple HIG separator
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 0.5)
                        .padding(.leading, 16)
                    
                    SettingToggleRow(
                        title: "Auto Record",
                        isOn: $settings.automaticallyRecord,
                        isEnabled: settings.enableRecording,
                        action: { enabled in
                            settings.updateAutomaticallyRecord(enabled)
                        }
                    )
                }
            }
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private func triggerAirPlayScreen() {
        // Create and present AirPlay route picker
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let _ = windowScene.windows.first {
                let routePickerView = AVRoutePickerView()
                routePickerView.prioritizesVideoDevices = true
                
                // Programmatically trigger the route picker
                for subview in routePickerView.subviews {
                    if let button = subview as? UIButton {
                        button.sendActions(for: .touchUpInside)
                        break
                    }
                }
            }
        }
    }
}

// MARK: - Setting Toggle Row
struct SettingToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var isEnabled: Bool = true
    let action: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 17, weight: .regular)) // Apple HIG standard body text
                .foregroundColor(isEnabled ? .white : .white.opacity(0.5))
                .multilineTextAlignment(.leading)
            
            Spacer(minLength: 8)
            
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { newValue in
                    if isEnabled {
                        isOn = newValue
                        action(newValue)
                    }
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1.0 : 0.6)
        }
        .padding(.horizontal, 16) // Apple HIG standard horizontal padding
        .padding(.vertical, 12)   // Apple HIG standard vertical padding for 44pt touch target
        .frame(minHeight: 44)     // Apple HIG minimum touch target
        .contentShape(Rectangle()) // Ensure entire row is tappable
        .onTapGesture {
            if isEnabled {
                isOn.toggle()
                action(isOn)
            }
        }
    }
}

// MARK: - Media Toggle Overlay (for Image/Video Mode)
struct MediaToggleOverlay: View {
    let orientationMode: OrientationMode
    let showingCamera: Bool
    let selectedImage: UIImage?
    let cameraManager: CameraManager
    let onToggleCameraImage: () -> Void
    
    var body: some View {
        // Simplified, always-visible layout
        ZStack {
            if orientationMode == .landscape {
                // Landscape: Button on right side, bottom position (match CameraControlsView)
                HStack {
                    Spacer()
                    
                    VStack(spacing: 30) {
                        Spacer()
                        Spacer() // Extra spacer for camera switch button position
                        Spacer() // Extra spacer for record button position
                        
                        // Position button at bottom right - same as camera mode
                        mediaToggleButton
                    }
                    .padding(.trailing, 20) // Match CameraControlsView exactly
                }
            } else {
                // Portrait: Button on bottom left (match CameraControlsView)
                VStack {
                    Spacer()
                    
                    HStack {
                        // Media toggle button in bottom LEFT (same as camera mode)
                        mediaToggleButton
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20) // Match CameraControlsView exactly
                    .padding(.bottom, 40) // Match CameraControlsView exactly
                }
            }
        }
        .onAppear {
            print("🎬 MediaToggleOverlay appeared - orientationMode: \(orientationMode), showingCamera: \(showingCamera)")
            print("🎬 MediaToggleOverlay - selectedImage: \(selectedImage != nil ? "present" : "nil")")
            print("🎬 MediaToggleOverlay - cameraManager.isRecording: \(cameraManager.isRecording)")
        }
        .onDisappear {
            print("🎬 MediaToggleOverlay disappeared")
        }
    }
    
    private var mediaToggleButton: some View {
        Button(action: {
            print("🎬 MediaToggleButton tapped! Switching back to camera mode")
            onToggleCameraImage()
        }) {
            ZStack {
                // White border ring (red if recording) - make it more visible for debugging
                Circle()
                    .fill(cameraManager.isRecording ? Color.red : Color.white)
                    .frame(width: 100, height: 100) // Increased size for debugging
                
                // Background circle - make it fully opaque for better visibility
                Circle()
                    .fill(Color.black)
                    .frame(width: 85, height: 85) // Increased size for debugging
                
                // Always show camera icon when in image/video mode (to switch back to camera)
                Image(systemName: "video.fill")
                    .font(.system(size: 30, weight: .bold)) // Larger and bolder
                    .foregroundColor(.white)
                
                // Recording indicator dot
                if cameraManager.isRecording {
                    VStack {
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                                .padding(.trailing, 8)
                                .padding(.top, 8)
                        }
                        Spacer()
                    }
                }
            }
            .shadow(color: .white, radius: 5) // Add white shadow for visibility
        }
        .buttonStyle(.plain)
        .onAppear {
            print("🎬 MediaToggleButton appeared!")
        }
    }
}

// MARK: - Simple Camera Toggle Button
struct SimpleCameraToggleButton: View {
    let orientationMode: OrientationMode
    let isRecording: Bool
    let onToggle: () -> Void
    
    var body: some View {
        ZStack {
            if orientationMode == .landscape {
                // Landscape: Button on right side, bottom position
                HStack {
                    Spacer()
                    
                    VStack {
                        Spacer()
                        Spacer() // Extra spacer for camera switch button position
                        Spacer() // Extra spacer for record button position
                        
                        toggleButton
                    }
                    .padding(.trailing, 20)
                }
            } else {
                // Portrait: Button on bottom left
                VStack {
                    Spacer()
                    
                    HStack {
                        toggleButton
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    private var toggleButton: some View {
        Button(action: {
            print("🎬 SimpleCameraToggleButton tapped!")
            onToggle()
        }) {
            ZStack {
                // White border ring (red if recording)
                Circle()
                    .fill(isRecording ? Color.red : Color.white)
                    .frame(width: 80, height: 80)
                
                // Background circle
                Circle()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: 70, height: 70)
                
                // Camera icon to indicate switching back to camera
                Image(systemName: "video.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                
                // Recording indicator dot
                if isRecording {
                    VStack {
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                                .padding(.trailing, 6)
                                .padding(.top, 6)
                        }
                        Spacer()
                    }
                    .frame(width: 80, height: 80)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AirPlay Button
struct AirPlayButton: UIViewRepresentable {
    @State private var isAirPlayConnected = false
    
    func makeUIView(context: Context) -> UIView {
        print("🎵 AirPlay: Creating AirPlay button view")
        let containerView = UIView()
        containerView.backgroundColor = UIColor.clear
        
        // Set up AirPlay status monitoring
        context.coordinator.setupAirPlayMonitoring(containerView: containerView)
        
        // Create custom button appearance - match Go Live button styling
        let button = UIButton(type: .system)
        button.setTitle("Connect to Apple TV", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        button.setTitleColor(UIColor.white, for: .normal)
        button.backgroundColor = UIColor.systemBlue
        button.layer.cornerRadius = 10
        button.isUserInteractionEnabled = false // Let route picker handle touches
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Add AirPlay icon
        let airplayIcon = UIImageView(image: UIImage(systemName: "airplay"))
        airplayIcon.tintColor = UIColor.white
        airplayIcon.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(button)
        button.addSubview(airplayIcon)
        
        // Create the route picker view with debug capabilities
        let routePickerView = DebugRoutePickerView()
        routePickerView.translatesAutoresizingMaskIntoConstraints = false
        routePickerView.alpha = 0.05 // Slightly more visible for better touch detection
        routePickerView.isUserInteractionEnabled = true
        routePickerView.backgroundColor = UIColor.clear
        routePickerView.activeTintColor = UIColor.white
        routePickerView.tintColor = UIColor.white.withAlphaComponent(0.7)
        
        // Configure for video destinations only
        routePickerView.prioritizesVideoDevices = true
        
        // Set up custom filtering for screen mirroring only
        context.coordinator.setupScreenMirroringFilter(routePickerView: routePickerView)
        
        // Filter to only show video/screen mirroring routes
        routePickerView.delegate = context.coordinator
        
        // Ensure the route picker has proper priority for receiving touches
        routePickerView.isExclusiveTouch = true
        
        print("🎵 AirPlay: RoutePickerView created with frame: \(routePickerView.frame)")
        print("🎵 AirPlay: RoutePickerView alpha: \(routePickerView.alpha), userInteractionEnabled: \(routePickerView.isUserInteractionEnabled)")
        
        containerView.addSubview(routePickerView)
        containerView.bringSubviewToFront(routePickerView) // Ensure route picker is on top
        
        // Connect the button to the route picker for visual feedback
        routePickerView.setBackgroundButton(button)
        
        print("🎵 AirPlay: RoutePickerView added to container and brought to front")
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Button constraints - fill container completely
            button.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            button.topAnchor.constraint(equalTo: containerView.topAnchor),
            button.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            // AirPlay icon constraints
            airplayIcon.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 16),
            airplayIcon.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            airplayIcon.widthAnchor.constraint(equalToConstant: 20),
            airplayIcon.heightAnchor.constraint(equalToConstant: 20),
            
            // Route picker constraints (covers the button)
            routePickerView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            routePickerView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            routePickerView.topAnchor.constraint(equalTo: button.topAnchor),
            routePickerView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        
        print("🎵 AirPlay: Constraints activated")
        print("🎵 AirPlay: Container subviews: \(containerView.subviews.count)")
        print("🎵 AirPlay: RoutePickerView superview: \(routePickerView.superview != nil ? "✅" : "❌")")
        
        // Force layout to ensure proper frame calculation
        containerView.layoutIfNeeded()
        
        print("🎵 AirPlay: Final container frame: \(containerView.frame)")
        print("🎵 AirPlay: Final button frame: \(button.frame)")
        print("🎵 AirPlay: Final routePickerView frame: \(routePickerView.frame)")
        
        return containerView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.updateButtonColor(containerView: uiView)
    }
    
    class Coordinator: NSObject, AVRoutePickerViewDelegate {
        private var button: UIButton?
        private var routePickerView: AVRoutePickerView?
        
        func setupScreenMirroringFilter(routePickerView: AVRoutePickerView) {
            self.routePickerView = routePickerView
            print("🎵 AirPlay: Setting up screen mirroring filter")
            
            // Configure audio session for video playback to filter for video destinations
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
                try audioSession.setActive(true)
                print("🎵 AirPlay: ✅ Audio session configured for video playback (.playback + .moviePlayback)")
            } catch {
                print("🎵 AirPlay: ❌ Failed to configure audio session: \(error)")
            }
        }
        
        func setupAirPlayMonitoring(containerView: UIView) {
            print("🎵 AirPlay: Setting up monitoring")
            
            // Find the button in the container
            for subview in containerView.subviews {
                if let btn = subview as? UIButton {
                    self.button = btn
                    print("🎵 AirPlay: Found button in container")
                    break
                }
            }
            
            // Monitor AirPlay status
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(audioRouteChanged),
                name: AVAudioSession.routeChangeNotification,
                object: nil
            )
            
            print("🎵 AirPlay: Audio route change observer added")
            
            // Initial status check
            updateButtonColor(containerView: containerView)
            
            // Check for available routes
            let audioSession = AVAudioSession.sharedInstance()
            let availableInputs = audioSession.availableInputs
            print("🎵 AirPlay: Available audio inputs: \(availableInputs?.count ?? 0)")
            
            let currentRoute = audioSession.currentRoute
            print("🎵 AirPlay: Current route outputs: \(currentRoute.outputs.count)")
            for output in currentRoute.outputs {
                print("🎵 AirPlay: Output - Type: \(output.portType.rawValue), Name: \(output.portName)")
            }
        }
        
        @objc func audioRouteChanged() {
            print("🎵 AirPlay: Audio route changed notification received")
            DispatchQueue.main.async {
                if let button = self.button {
                    let isConnected = self.isAirPlayActive()
                    print("🎵 AirPlay: Route changed - isConnected: \(isConnected)")
                    button.backgroundColor = isConnected ? UIColor.systemGreen.withAlphaComponent(0.8) : UIColor.systemBlue
                    button.setTitle(isConnected ? "Connected to Apple TV" : "Connect to Apple TV", for: .normal)
                }
            }
        }
        
        func updateButtonColor(containerView: UIView) {
            // Find button and update color and text based on AirPlay status
            for subview in containerView.subviews {
                if let button = subview as? UIButton {
                    let isConnected = isAirPlayActive()
                    button.backgroundColor = isConnected ? UIColor.systemGreen.withAlphaComponent(0.8) : UIColor.systemBlue
                    button.setTitle(isConnected ? "Connected to Apple TV" : "Connect to Apple TV", for: .normal)
                    self.button = button
                    break
                }
            }
        }
        
        private func isAirPlayActive() -> Bool {
            let audioSession = AVAudioSession.sharedInstance()
            let currentRoute = audioSession.currentRoute
            
            print("🎵 AirPlay: Checking if AirPlay is active...")
            print("🎵 AirPlay: Current route has \(currentRoute.outputs.count) outputs")
            
            for output in currentRoute.outputs {
                print("🎵 AirPlay: Checking output - Type: \(output.portType.rawValue), Name: \(output.portName)")
                if output.portType == .airPlay {
                    print("🎵 AirPlay: ✅ AirPlay output found!")
                    return true
                }
            }
            print("🎵 AirPlay: ❌ No AirPlay output found")
            return false
        }
        
        // MARK: - AVRoutePickerViewDelegate
        func routePickerViewWillBeginPresentingRoutes(_ routePickerView: AVRoutePickerView) {
            print("🎵 AirPlay: 📺 Will begin presenting routes (AirPlay menu opening)")
            
            // Log available routes for debugging
            let audioSession = AVAudioSession.sharedInstance()
            let currentRoute = audioSession.currentRoute
            print("🎵 AirPlay: 📺 Current audio session category: \(audioSession.category)")
            print("🎵 AirPlay: 📺 Current audio session mode: \(audioSession.mode)")
            print("🎵 AirPlay: 📺 Available routes: \(currentRoute.outputs.count)")
            for output in currentRoute.outputs {
                print("🎵 AirPlay: 📺 Route - Type: \(output.portType.rawValue), Name: \(output.portName)")
            }
        }
        
        func routePickerViewDidEndPresentingRoutes(_ routePickerView: AVRoutePickerView) {
            print("🎵 AirPlay: 📺 Did end presenting routes (AirPlay menu closed)")
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

#Preview {
    ContentView()
}
