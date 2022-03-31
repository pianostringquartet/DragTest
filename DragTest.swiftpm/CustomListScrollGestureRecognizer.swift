//
//  CustomListScrollgestureRecognizer.swift
//  DragTest
//
//  Created by Christian J Clampitt on 3/30/22.
//

import Foundation
import SwiftUI

// Handles:
// - two fingers on trackpad list-scrolling
// - one finger on screen list-scrolling

struct CustomListScrollGestureRecognizer<T: View>: UIViewControllerRepresentable {
//struct UIGestureOverlayView: UIViewControllerRepresentable {

//    let content: ScrollableListView
    let content: T
    
    let onScrollChanged: OnDragChangedHandler
    let onScrollEnded: OnDragEndedHandler

    func makeUIViewController(context: Context) -> CustomListScrollGestureVC<T> {
        CustomListScrollGestureVC(content: UIHostingController(rootView: content),
                           onScrollChanged: onScrollChanged,
                           onScrollEnded: onScrollEnded)
    }

    func updateUIViewController(_ uiViewController: CustomListScrollGestureVC<T>,
                                context: Context) {
        uiViewController.swiftUIContent.rootView = content
    }
}

// Embed a SwiftUI view in a UIView which contains UIKit gesture recognizers.
// User interactions reach both the UIView and SwiftUI views.
class CustomListScrollGestureVC<T: View>: UIViewController {

    var swiftUIContent: UIHostingController<T>
    
    let onScrollChanged: OnDragChangedHandler?
    let onScrollEnded: OnDragEndedHandler?

    init(content: UIHostingController<T>,
         onScrollChanged: OnDragChangedHandler?,
         onScrollEnded: OnDragEndedHandler?) {
    
        self.swiftUIContent = content
        self.onScrollChanged = onScrollChanged
        self.onScrollEnded = onScrollEnded
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Proper sizing of the embedded SwiftUI View
        // ie. 'false' = we will manually set UIView ourselves
        swiftUIContent.view.translatesAutoresizingMaskIntoConstraints = false

        // Add view (UIHostingContoller) to parent UIView
        view.addSubview(swiftUIContent.view)

        // Set view's bounds to be same as parent's (= fullscreen)
        swiftUIContent.view.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        swiftUIContent.view.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        swiftUIContent.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        swiftUIContent.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        swiftUIContent.didMove(toParent: self)

        // Add UIGestureRecognizers
        let trackpadPanGesture = UIPanGestureRecognizer(
            target: self,
            action: #selector(self.scrollGestureHandler))
        trackpadPanGesture.allowedScrollTypesMask = [.continuous, .discrete]
        self.view.addGestureRecognizer(trackpadPanGesture)
    }
    
    // touches = 1 is trackpad click and drag
    // touches = 0 is trackpad panning around graph
    // In the overlay, we're only interested in click-less trackpad panning.
    @objc func scrollGestureHandler(_ gestureRecognizer: UIPanGestureRecognizer) {
        
        log("CustomListScrollGestureVC: scrollGestureHandler: gestureRecognizer.numberOfTouches: \(gestureRecognizer.numberOfTouches)")
        
        guard let onScrollEnded = onScrollEnded,
              let onScrollChanged = onScrollChanged else {
                  log("CustomListScrollGestureVC: scrollGestureHandler: handlers not ready")
            return
        }
        
        let translation = gestureRecognizer.translation(in: self.view)

        // ie finger on screen
        if gestureRecognizer.numberOfTouches == 1 {
            switch gestureRecognizer.state {
            case .changed:
                log("CustomListScrollGestureVC: scrollGestureHandler: touches=1: .changed")
                onScrollChanged(translation.y)
            default:
                log("CustomListScrollGestureVC: default")
                break
            }
        }
        
        // was a trackpad pan (no click);
        // always move the graph, even if our cursor is over a node.
        else if gestureRecognizer.numberOfTouches == 0 {
            switch gestureRecognizer.state {
            case .changed:
                log("CustomListScrollGestureVC: scrollGestureHandler: touches=0: .changed")
                onScrollChanged(translation.y)
            case .ended, .cancelled:
                log("CustomListScrollGestureVC: scrollGestureHandler: touches=0: .cancelled or .ended")
                onScrollEnded()
            default:
                break
            }
        } else {
            log("CustomListScrollGestureVC: scrollGestureHandler: incorrect number of touches; doing nothing")
        }
    }
}
