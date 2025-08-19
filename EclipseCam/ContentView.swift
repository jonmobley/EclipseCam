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
            } else if showCameraView {
                CameraView(orientationMode: selectedMode, preSelectedImage: preSelectedImage) {
                    // Back button callback  
                    showCameraView = false
                    // Set back to portrait for main menu
                    OrientationManager.shared.setOrientation(UIInterfaceOrientation.portrait)
                }
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
                    
                    // Instructions section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Instructions")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        
                        Text("In LIVE mode, double tap the screen to switch between the Camera and Image. Long press to exit.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 40) // Increased spacing from thumbnail
                    
                    Spacer() // Push buttons to bottom
                    
                    VStack(spacing: 8) { // Apple HIG standard spacing for related buttons
                        // AirPlay Connect button
                        AirPlayButton()
                            .frame(height: 50) // Match Go Live button height
                            .padding(.horizontal, 20)
                        
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
                    }
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
    @State private var showingImagePicker = false
    @State private var showingFullscreenImage = false
    @State private var showingCamera = true // Track whether to show camera or image
    
    var body: some View {
        ZStack {
            // Black background for clean AirPlay appearance
            Color.black.ignoresSafeArea()
            
            // Main content with tap gestures - toggles between camera and image
            ZStack {
                if showingCamera {
                    // Show camera preview
                    if cameraManager.isAuthorized {
                        // Live camera preview
                        CameraPreview(session: cameraManager.session, orientationMode: orientationMode)
                            .ignoresSafeArea()
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
                } else if let image = selectedImage {
                    // Show selected image
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()
                        .clipped()
                }
            }
            .onTapGesture(count: 2) {
                // Double tap: Switch camera
                if cameraManager.isAuthorized {
                    cameraManager.switchCamera()
                }
            }
            .onTapGesture(count: 1) {
                // Single tap: Toggle between camera and image
                if selectedImage != nil {
                    showingCamera.toggle()
                }
                // If no image selected, single tap does nothing (only camera is shown)
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
        .statusBarHidden(true) // Hide status bar for clean streaming appearance
        .onAppear {
            // Initialize with pre-selected image if available
            if selectedImage == nil {
                selectedImage = preSelectedImage
            }
            cameraManager.configure(for: orientationMode)
            // Small delay to ensure configuration is complete before starting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                cameraManager.startSession()
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .sheet(isPresented: $showingImagePicker) {
            EnhancedImagePicker(
                selectedImage: $selectedImage,
                onImageSelected: { image, isFromHistory in
                    // Only add to history if it's from camera roll, not from history
                    if !isFromHistory {
                        MediaHistoryManager.shared.addToHistory(image)
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showingFullscreenImage) {
            if let image = selectedImage {
                FullscreenImageView(image: image, onDismiss: {
                    showingFullscreenImage = false
                }, onBack: onBack)
            }
        }
    }
}

// MARK: - Image Picker
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

// MARK: - Fullscreen Image View
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
        .statusBarHidden(true)
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
        button.setTitle("Connect to AirPlay", for: .normal)
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
                    button.setTitle(isConnected ? "AirPlay Connected" : "Connect to AirPlay", for: .normal)
                }
            }
        }
        
        func updateButtonColor(containerView: UIView) {
            // Find button and update color and text based on AirPlay status
            for subview in containerView.subviews {
                if let button = subview as? UIButton {
                    let isConnected = isAirPlayActive()
                    button.backgroundColor = isConnected ? UIColor.systemGreen.withAlphaComponent(0.8) : UIColor.systemBlue
                    button.setTitle(isConnected ? "AirPlay Connected" : "Connect to AirPlay", for: .normal)
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
