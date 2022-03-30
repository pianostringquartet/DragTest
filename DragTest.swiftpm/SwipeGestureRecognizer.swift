//
//  File.swift
//  DragTest
//
//  Created by Christian J Clampitt on 3/28/22.
//

import Foundation
import UIKit
import SwiftUI

//typealias OnSwipeDragChanged = (CGFloat) -> ()
typealias OnSwipeDragChanged = (CGSize) -> ()
typealias OnSwipeDragEnded = () -> ()

struct SwipeGestureRecognizerView: UIViewControllerRepresentable {

    let onDragChanged: OnSwipeDragChanged
    let onDragEnded: OnSwipeDragEnded
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<SwipeGestureRecognizerView>) -> SwipeGestureRecognizerVC {
        SwipeGestureRecognizerVC(onDragChanged: onDragChanged,
                                 onDragEnded: onDragEnded)
    }

    func updateUIViewController(_ uiView: SwipeGestureRecognizerVC,
                                context: Context) { }
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

    @objc func panInView(_ gestureRecognizer: UIPanGestureRecognizer) {

        log("SwipeGestureRecognizerVC: screenPanInView: gestureRecognizer.numberOfTouches:  \(gestureRecognizer.numberOfTouches)")

        // `touches == 0` = running our fingers on trackpad, but no click
        guard gestureRecognizer.numberOfTouches == 0 else {
            log("SwipeGestureRecognizerVC: screenPanInView: incorrect number of touches; will do nothing")
            return
        }
        
        switch gestureRecognizer.state {
        
        case .changed:
            log("SwipeGestureRecognizerVC: screenPanInView: changed")
            if let onDragChanged = onDragChanged {
                let translation = gestureRecognizer.translation(in: self.view)
                let translationSize = CGSize(width: translation.x, height: translation.y)
                onDragChanged(translationSize)
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
extension SwipeGestureRecognizerVC: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
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
