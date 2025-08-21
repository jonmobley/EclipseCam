//
//  HomeIndicatorController.swift
//  EclipseCam
//
//  Created by Jon Mobley on 8/19/25.
//

import UIKit
import SwiftUI

// MARK: - Custom Hosting Controller
class HomeIndicatorHostingController<Content: View>: UIHostingController<Content> {
    var homeIndicatorAutoHidden = false
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return homeIndicatorAutoHidden
    }
    
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return homeIndicatorAutoHidden ? .all : []
    }
    
    func setHomeIndicatorAutoHidden(_ hidden: Bool) {
        homeIndicatorAutoHidden = hidden
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
    }
}

// MARK: - View Modifier for Home Indicator Control
struct HomeIndicatorHiddenModifier: ViewModifier {
    let isHidden: Bool
    
    func body(content: Content) -> some View {
        content
            .background(HomeIndicatorControllerRepresentable(isHidden: isHidden))
            .persistentSystemOverlays(isHidden ? .hidden : .automatic)
    }
}

// MARK: - Enhanced System UI Hiding Modifier
struct SystemUIHiddenModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(EnhancedSystemUIController())
            .persistentSystemOverlays(.hidden)
            .statusBarHidden(true)
    }
}

// MARK: - Enhanced System UI Controller
struct EnhancedSystemUIController: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = EnhancedSystemUIViewController()
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Force update of system UI preferences
        uiViewController.setNeedsUpdateOfHomeIndicatorAutoHidden()
        uiViewController.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
    }
}

// MARK: - Enhanced System UI View Controller
class EnhancedSystemUIViewController: UIViewController {
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return .all
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        
        // Force immediate update
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        setNeedsStatusBarAppearanceUpdate()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Force update again when view appears
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        setNeedsStatusBarAppearanceUpdate()
    }
}

// MARK: - UIViewControllerRepresentable for Home Indicator Control
struct HomeIndicatorControllerRepresentable: UIViewControllerRepresentable {
    let isHidden: Bool
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = HomeIndicatorViewController()
        controller.isHomeIndicatorHidden = isHidden
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let controller = uiViewController as? HomeIndicatorViewController {
            controller.isHomeIndicatorHidden = isHidden
        }
    }
}

// MARK: - Custom UIViewController for Home Indicator Control
class HomeIndicatorViewController: UIViewController {
    var isHomeIndicatorHidden = false {
        didSet {
            setNeedsUpdateOfHomeIndicatorAutoHidden()
            setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        }
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return isHomeIndicatorHidden
    }
    
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return isHomeIndicatorHidden ? .all : []
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
    }
}

// MARK: - View Extension
extension View {
    func homeIndicatorHidden(_ hidden: Bool = true) -> some View {
        self.modifier(HomeIndicatorHiddenModifier(isHidden: hidden))
    }
    
    func fullscreenMode() -> some View {
        self
            .statusBarHidden(true)
            .persistentSystemOverlays(.hidden)
            .homeIndicatorHidden(true)
            .ignoresSafeArea()
    }
    
    func airPlayMode() -> some View {
        self
            .modifier(SystemUIHiddenModifier())
            .homeIndicatorHidden(true)
            .ignoresSafeArea()
            .allowsHitTesting(true) // Ensure touch events are handled by our controls
    }
    
    func localCameraMode() -> some View {
        self
            .statusBarHidden(false) // Keep status bar visible locally
            .homeIndicatorHidden(true) // Hide home indicator for immersive experience
            .ignoresSafeArea(.container, edges: .bottom) // Only ignore bottom safe area
    }
}
