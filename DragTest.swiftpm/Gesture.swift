//
//  File.swift
//  DragTest
//
//  Created by Christian J Clampitt on 3/28/22.
//

import Foundation
import UIKit
import SwiftUI


//typealias OnSwipeDragChanged = (DragGesture.Value) -> ()
typealias OnSwipeDragChanged = (CGFloat) -> ()
typealias OnSwipeDragEnded = () -> ()

struct SwipeGestureRecognizerView: UIViewControllerRepresentable {

    let onDragChanged: OnSwipeDragChanged
    let onDragEnded: OnSwipeDragEnded
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<SwipeGestureRecognizerView>) -> SwipeGestureRecognizerVC {
        log("SwipeGestureRecognizerView: makeUIViewController")
//        return SwipeGestureRecognizerVC()
        return SwipeGestureRecognizerVC(onDragChanged: onDragChanged,
                                        onDragEnded: onDragEnded)
    }

    func updateUIViewController(_ uiView: SwipeGestureRecognizerVC,
                                context: Context) {
        log("SwipeGestureRecognizerView: makeUIViewController")
    }
}

class SwipeGestureRecognizerVC: UIViewController {

    let onDragChanged: OnSwipeDragChanged?
    let onDragEnded: OnSwipeDragEnded?
    
    init(onDragChanged: OnSwipeDragChanged?,
         onDragEnded: OnSwipeDragEnded?) {
        
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
        
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillLayoutSubviews() {
        self.view.backgroundColor = .clear
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let trackpadTouch = NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)

        let trackpadPanGesture = UIPanGestureRecognizer(
            target: self,
            action: #selector(self.panInView))
        trackpadPanGesture.allowedScrollTypesMask = [.continuous, .discrete]
        // ignore screen; uses trackpad
        trackpadPanGesture.allowedTouchTypes = [trackpadTouch]
        trackpadPanGesture.delegate = self
        self.view.addGestureRecognizer(trackpadPanGesture)
    }

    // only intended for a single finger on the screen;
    // two fingers on the screen is a pinch, not a pan, gesture
    @objc func panInView(_ gestureRecognizer: UIPanGestureRecognizer) {

        log("SwipeGestureRecognizerVC: screenPanInView: gestureRecognizer.numberOfTouches:  \(gestureRecognizer.numberOfTouches)")

        // `touches == 0` = we're just running our fingers on the trackpad
        guard gestureRecognizer.numberOfTouches == 0 else {
            log("SwipeGestureRecognizerVC: screenPanInView: incorrect number of touches; will do nothing")
            return 
        }
        
        switch gestureRecognizer.state {
        
        case .changed:
            log("SwipeGestureRecognizerVC: screenPanInView: changed")
            if let onDragChanged = onDragChanged {
                let translation = gestureRecognizer.translation(in: self.view)
                onDragChanged(translation.x)
            }
            
        case .ended, .cancelled:
            log("SwipeGestureRecognizerVC: screenPanInView: ended or cancelled")
            if let onDragEnded = onDragEnded {
                onDragEnded()
            }
            
        default:
            log("SwipeGestureRecognizerVC: screenPanInView: default")
            break
        }
    }
    
}

// Enables simultaneous gestures with SwiftUI gesture handlers
// Pan gestures are cancelled by pinch gestures.
extension SwipeGestureRecognizerVC: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        log("\n \n SwipeGestureRecognizerVC: shouldRecognizeSimultaneouslyWith")
        log("SwipeGestureRecognizerVC: gestureRecognizer: \(gestureRecognizer)")
        log("SwipeGestureRecognizerVC: otherGestureRecognizer: \(otherGestureRecognizer)")

        return true
    }
}

func printGestureState(_ state: UIGestureRecognizer.State) {
    switch state {
    case .began:
        log("printGestureState: began")
    case .changed:
        log("printGestureState: changed")
    case .ended:
        log("printGestureState: ended")
    case .cancelled:
        log("printGestureState: cancelled")
    default:
        log("printGestureState: default")
    }
}
