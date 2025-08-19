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
        return homeIndicatorAutoHidden ? .bottom : []
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
        return isHomeIndicatorHidden ? .bottom : []
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
}
