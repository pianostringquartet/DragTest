//
//  SwipeGestureRecognizer.swift
//  DragTest
//
//  Created by Christian J Clampitt on 3/28/22.
//

import Foundation
import UIKit
import SwiftUI

// CGFloat: height if for item-drag; width if for item-swipe
typealias OnDragChangedHandler = (CGFloat) -> ()
typealias OnDragEndedHandler = () -> ()

// Gesture Recognizer attached to the Item itself,
// to detect trackpad 2-finger pans (for swipe)
// or trackpad click + drag (for immediate item dragging)

// a gesture recognizer for the item in the custom list itself
struct CustomListItemGestureRecognizerView: UIViewControllerRepresentable {

    let onItemSwipeChanged: OnDragChangedHandler
    let onItemSwipeEnded: OnDragEndedHandler
    
    let onItemDragChanged: OnDragChangedHandler
    let onItemDragEnded: OnDragEndedHandler
    
    let onScrollChanged: OnDragChangedHandler
    let onScrollEnded: OnDragEndedHandler
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<CustomListItemGestureRecognizerView>) -> SwipeGestureRecognizerVC {
        SwipeGestureRecognizerVC(onItemSwipeChanged: onItemSwipeChanged,
                                 onItemSwipeEnded: onItemSwipeEnded,
                                 onItemDragChanged: onItemDragChanged,
                                 onItemDragEnded: onItemDragEnded,
                                 onScrollChanged: onScrollChanged,
                                 onScrollEnded: onScrollEnded)
    }

    func updateUIViewController(_ uiView: SwipeGestureRecognizerVC,
                                context: Context) { }
}



// Handles:
// - one finger on screen item-swiping
// - two fingers on trackpad item-swiping
// - click on trackpad item-dragging

// Handled elsewhere:
// - one finger long-press-drag item-dragging: see `SwiftUI .simultaneousGesture`
// - two fingers on trackpad list scrolling

class SwipeGestureRecognizerVC: UIViewController {
    
    let onItemSwipeChanged: OnDragChangedHandler?
    let onItemSwipeEnded: OnDragEndedHandler?
    
    let onItemDragChanged: OnDragChangedHandler?
    let onItemDragEnded: OnDragEndedHandler?
    
    let onScrollChanged: OnDragChangedHandler?
    let onScrollEnded: OnDragEndedHandler?
        
    init(onItemSwipeChanged: OnDragChangedHandler?,
         onItemSwipeEnded: OnDragEndedHandler?,
         onItemDragChanged: OnDragChangedHandler?,
         onItemDragEnded: OnDragEndedHandler?,
         onScrollChanged: OnDragChangedHandler?,
         onScrollEnded: OnDragEndedHandler?) {
        
        self.onItemSwipeChanged = onItemSwipeChanged
        self.onItemSwipeEnded = onItemSwipeEnded
        
        self.onItemDragChanged = onItemDragChanged
        self.onItemDragEnded = onItemDragEnded
        
        self.onScrollChanged = onScrollChanged
        self.onScrollEnded = onScrollEnded
        
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
        
        let screenTouch = NSNumber(value: UITouch.TouchType.direct.rawValue)
        let trackpadTouch = NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)

        let screenPanGesture = UIPanGestureRecognizer(
            target: self,
            action: #selector(self.screenGestureHandler))
        screenPanGesture.allowedScrollTypesMask = [.continuous, .discrete]
        // uses screen; ignore trackpad
        screenPanGesture.allowedTouchTypes = [screenTouch]
        screenPanGesture.delegate = self
        self.view.addGestureRecognizer(screenPanGesture)
                
        let trackpadPanGesture = UIPanGestureRecognizer(
            target: self,
            action: #selector(self.trackpadGestureHandler))
        trackpadPanGesture.allowedScrollTypesMask = [.continuous, .discrete]
        // ignore screen; uses trackpad
        trackpadPanGesture.allowedTouchTypes = [trackpadTouch]
        trackpadPanGesture.delegate = self
        self.view.addGestureRecognizer(trackpadPanGesture)
    }

    // finger on screen
    @objc func screenGestureHandler(_ gestureRecognizer: UIPanGestureRecognizer) {

        log("SwipeGestureRecognizerVC: screenGestureHandler: gestureRecognizer.numberOfTouches:  \(gestureRecognizer.numberOfTouches)")
                
        // for finger on screen, we'll still use long press + drag for item-dragging;
        // so we'll still use a SwiftUI long-press-drag gesture
        // (unless we accidentally trigger both, via trackpad?)
        guard let onItemSwipeChanged = onItemSwipeChanged,
              let onItemSwipeEnded = onItemSwipeEnded,
              let onScrollChanged = onScrollChanged,
              let onScrollEnded = onScrollEnded else {
                  log("SwipeGestureRecognizerVC: screenGestureHandler: handlers not ready")
            return
        }
        
        let translation = gestureRecognizer.translation(in: self.view)
        
        // one finger on screen: can be item-drag or item-swipe;
        // since SwiftUI was doing both via simultaneous gestures,
        // just call both handlers here
        
        if gestureRecognizer.numberOfTouches == 1 {
            switch gestureRecognizer.state {
            case .changed:
                log("SwipeGestureRecognizerVC: screenGestureHandler: changed")
                onScrollChanged(translation.y)
                onItemSwipeChanged(translation.x)
            default:
                break // do nothing
            }
        }

        // When the finger-on-the-screen gesture is ended or cancelled, touches=0
        else if gestureRecognizer.numberOfTouches == 0 {
            log("SwipeGestureRecognizerVC: screenGestureHandler: 0 touches ")
            switch gestureRecognizer.state {
            case .ended, .cancelled:
                log("SwipeGestureRecognizerVC: screenGestureHandler: ended, cancelled")
                onScrollEnded()
                onItemSwipeEnded()
            default:
                break
            }
        } else {
            log("SwipeGestureRecognizerVC: screenGestureHandler: incorrect number of touches; will do nothing")
        }
        
    } // screenGestureHandler
    
    @objc func trackpadGestureHandler(_ gestureRecognizer: UIPanGestureRecognizer) {

        log("SwipeGestureRecognizerVC: trackpadGestureHandler: gestureRecognizer.numberOfTouches:  \(gestureRecognizer.numberOfTouches)")
        
        guard let onItemSwipeChanged = onItemSwipeChanged,
              let onItemSwipeEnded = onItemSwipeEnded,
              let onItemDragChanged = onItemDragChanged,
              let onItemDragEnded = onItemDragEnded else {
                  log("SwipeGestureRecognizerVC: trackpadGestureHandler: handlers not ready")
            return
        }
        
        let translation = gestureRecognizer.translation(in: self.view)
        
        // when we have clicked+dragged, and then let up our finger,
        // is that a touches=0 gesture?
        
        // `touches == 0` = running our fingers on trackpad, but no click
        if gestureRecognizer.numberOfTouches == 0 {
            switch gestureRecognizer.state {
            
            case .changed:
                log("SwipeGestureRecognizerVC: touches 0: trackpadGestureHandler: changed")
                onItemSwipeChanged(translation.x)
            case .ended, .cancelled:
                log("SwipeGestureRecognizerVC: touches 0: trackpadGestureHandler: ended or cancelled")
                onItemSwipeEnded()
                
                // would it be okay to fire this here?
                // ie if we weren't dragging the item,
                // then setting previousY = y is a noop;
                // and if were dragging, then setting activeGesture = .none is okay
                
                // ... what if we had been dragging, and we call on-swipe-ended?
                // ... should be okay, because activeGesture = .drag,
                // and on-swipe-ended is a noop when aG != .swipe
                onItemDragEnded()
                
            default:
                log("SwipeGestureRecognizerVC: touches 0: trackpadGestureHandler: default")
                break
            }
        }
        
        // `touches == 1` = click + drag
        else if gestureRecognizer.numberOfTouches == 1 {
            switch gestureRecognizer.state {
            case .changed:
                log("SwipeGestureRecognizerVC: trackpadGestureHandler: changed")
                onItemDragChanged(translation.y)
            default:
                log("SwipeGestureRecognizerVC: trackpadGestureHandler: default")
                break
            }
        }
    } // trackpadGestureHandler
    
}


// Enables simultaneous gestures with SwiftUI gesture handlers
// REQUIRED.
extension SwipeGestureRecognizerVC: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
