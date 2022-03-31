//
//  File.swift
//  DragTest
//
//  Created by Christian J Clampitt on 3/30/22.
//

import Foundation
import SwiftUI


//struct UIGestureOverlayView<T: View>: UIViewControllerRepresentable {
struct UIGestureOverlayView: UIViewControllerRepresentable {

    let content: ScrollableListView
    
    let onScrollChanged: OnDragChangedHandler
    let onScrollEnded: OnDragEndedHandler

//    func makeUIViewController(context: Context) -> UIGestureOverlayVC<T> {
    func makeUIViewController(context: Context) -> UIGestureOverlayVC {
        UIGestureOverlayVC(content: UIHostingController(rootView: content),
                           onScrollChanged: onScrollChanged,
                           onScrollEnded: onScrollEnded)
    }

//    func updateUIViewController(_ uiViewController: UIGestureOverlayVC<T>,
    func updateUIViewController(_ uiViewController: UIGestureOverlayVC,
                                context: Context) {
        uiViewController.swiftUIContent.rootView = content
    }
}

// Embed a SwiftUI view in a UIView which contains UIKit gesture recognizers.
// User interactions reach both the UIView and SwiftUI views.
//class UIGestureOverlayVC<T: View>: UIViewController {
class UIGestureOverlayVC: UIViewController {

//    var swiftUIContent: UIHostingController<T>
    var swiftUIContent: UIHostingController<ScrollableListView>
    
    let onScrollChanged: OnDragChangedHandler?
    let onScrollEnded: OnDragEndedHandler?

//    init(content: UIHostingController<T>) {
//    init(content: UIHostingController<T>,
    init(content: UIHostingController<ScrollableListView>,
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

        let screenTouch = NSNumber(value: UITouch.TouchType.direct.rawValue)
        let trackpadTouch = NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)

        let trackpadPanGesture = UIPanGestureRecognizer(
            target: self,
            action: #selector(self.trackpadPanInView))
        trackpadPanGesture.allowedScrollTypesMask = [.continuous, .discrete]
        // ignore screen; uses trackpad
//        trackpadPanGesture.allowedTouchTypes = [trackpadTouch]
        self.view.addGestureRecognizer(trackpadPanGesture)
    }

    // also need screen gesture handler for scroll
    // since you no longer have
    
    
    
    
    
    // touches = 1 is trackpad click and drag
    // touches = 0 is trackpad panning around graph
    // In the overlay, we're only interested in click-less trackpad panning.
    @objc func trackpadPanInView(_ gestureRecognizer: UIPanGestureRecognizer) {
        
        log("UIGestureOverlayVC: trackpadPanInView: gestureRecognizer.numberOfTouches: \(gestureRecognizer.numberOfTouches)")
        
        guard let onScrollEnded = onScrollEnded,
              let onScrollChanged = onScrollChanged else {
                  log("UIGestureOverlayVC: trackpadPanInView: handlers not ready")
            return
        }
        
        let translation = gestureRecognizer.translation(in: self.view)

        // ie finger on screen
        if gestureRecognizer.numberOfTouches == 1 {
            switch gestureRecognizer.state {
            case .changed:
                log("UIGestureOverlayVC: trackpadPanInView: touches=1: .changed")
                onScrollChanged(translation.y)
            default:
                log("UIGestureOverlayVC: default")
                break
            }
        }
        
        // was a trackpad pan (no click);
        // always move the graph, even if our cursor is over a node.
        else if gestureRecognizer.numberOfTouches == 0 {
            switch gestureRecognizer.state {
            case .changed:
                log("UIGestureOverlayVC: trackpadPanInView: touches=0: .changed")
                onScrollChanged(translation.y)
            case .ended, .cancelled:
                log("UIGestureOverlayVC: trackpadPanInView: touches=0: .cancelled or .ended")
                onScrollEnded()
            default:
                break
            }
        } else {
            log("UIGestureOverlayVC: trackpadPanInView: incorrect number of touches; doing nothing")
        }
    }
}

// Add delegate to allow for simultaneous touches with SwiftUI and other UIKit gestures?
//

extension UIGestureOverlayVC: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
