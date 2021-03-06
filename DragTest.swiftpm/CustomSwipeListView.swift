//
//  CustomSwipeListView.swift
//  DragTest
//
//  Created by Christian J Clampitt on 3/30/22.
//

import Foundation
import SwiftUI

typealias LongPressAndDragGestureType = SequenceGesture<_EndedGesture<LongPressGesture>, DragGestureType>
typealias DragGestureType = _EndedGesture<_ChangedGesture<DragGesture>>

enum ActiveGesture: Equatable {
    case scrolling, // scrolling the entire list
         dragging(Int), // drag or (long press + drag); on a single item
         swiping, // swiping single item
         none
    
    var isScroll: Bool {
        switch self {
        case .scrolling:
            return true
        default:
            return false
        }
    }
    
    var isDrag: Bool {
        switch self {
        case .dragging:
            return true
        default:
            return false
        }
    }
    
    var dragId: Int? {
        switch self {
        case .dragging(let x):
            return x
        default:
            return nil
        }
    }
    
    var isSwipe: Bool {
        switch self {
        case .swiping:
            return true
        default:
            return false
        }
    }
    
    var isNone: Bool {
        switch self {
        case .none:
            return true
        default:
            return false
        }
    }
}

let SCROLL_THRESHOLD: CGFloat = 20
let SWIPE_THRESHOLD: CGFloat = 20


// need a specific type for passing to UIOverlayVC ?
struct ScrollableListView: View {
    
    let onScrollChanged: OnDragChangedHandler
    let onScrollEnded: OnDragEndedHandler
    
    @Binding var activeSwipeId: Int?
    
    let isBeingEdited: Bool
    
    @Binding var activeGesture: ActiveGesture
    
    // was: `var listView` inside
    var body: some View {
        
        ZStack {
            
            SwipeView(id: 1,
                      activeSwipeId: $activeSwipeId,
                      itemY: 0,
                      itemPreviousY: 0,
                      isBeingEdited: isBeingEdited,
                      activeGesture: $activeGesture,
                      onScrollChanged: onScrollChanged,
                      onScrollEnded: onScrollEnded)
            
            SwipeView(id: 2,
                      activeSwipeId: $activeSwipeId,
//                      y: 60,
//                      previousY: 60,
                      itemY: 300,
                      itemPreviousY: 300,
                      isBeingEdited: isBeingEdited,
                      activeGesture: $activeGesture,
                      onScrollChanged: onScrollChanged,
                      onScrollEnded: onScrollEnded)
            
//            SwipeView(id: 3,
//                      activeSwipeId: $activeSwipeId,
//                      y: 120,
//                      previousY: 120,
//                      isBeingEdited: isBeingEdited,
//                      activeGesture: $activeGesture)
//            SwipeView(id: 4,
//                      activeSwipeId: $activeSwipeId,
//                      y: 180,
//                      previousY: 180,
//                      isBeingEdited: isBeingEdited,
//                      activeGesture: $activeGesture)
//            SwipeView(id: 5,
//                      activeSwipeId: $activeSwipeId,
//                      y: 240,
//                      previousY: 240,
//                      isBeingEdited: isBeingEdited,
//                      activeGesture: $activeGesture)
        }
    }
    
}



struct SwipeListView: View {
    
    @State var activeSwipeId: Int? = nil
    
    // position of list itself; scrolling etc.
    @State var y: CGFloat = 0
    @State var previousY: CGFloat = 0

    @State var isBeingEdited = false
    
    @State var activeGesture: ActiveGesture = .none
    
    var debugInfo: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("list y: \(y)")
                Text("list previousY: \(previousY)")
            }
//                Rectangle().fill(.clear).frame(width: 250)
            Rectangle().fill(.clear).frame(width: 10)
            Text("EDIT MODE?: \(isBeingEdited.description)").onTapGesture {
                isBeingEdited.toggle()
            }
//                VStack(alignment: .leading) {
//                    Text("Gesture")
//                    Text(" \(activeGesture.debugDescription)")
//                        .frame(width: 350)
//                        .border(.green)
//
//                }
        }
        .scaleEffect(1.5)
    }
    
    var onScrollChanged: OnDragChangedHandler {
        return { (translationHeight: CGFloat) in
            print("onScrollChanged")
            
            // if we're not in the middle opf
            if activeGesture.isNone
                && translationHeight.magnitude > SCROLL_THRESHOLD {
                print("onScrollChanged: setting us to scroll")
                activeGesture = .scrolling
            }
            
            if activeGesture.isScroll {
                print("onScrollChanged: updating per scroll")
                y = translationHeight + previousY
            }
        }
    }
    
    var onScrollEnded: OnDragEndedHandler {
        return {
            print("onScrollEnded")
            
            if activeGesture.isScroll {
                print("onScrollEnded: resetting scroll")
                activeGesture = .none
                previousY = y
            }
        }
    }
    
    var scrollDrag: DragGestureType {
        let scrollDrag: DragGestureType = DragGesture()
            .onChanged { value in
                onScrollChanged(value.translation.height)
                
            }.onEnded { value in
                onScrollEnded()
            }
        return scrollDrag
    }
    

    var body: some View {

//        let scrollDrag: DragGestureType = DragGesture()
//            .onChanged { value in
//                print("scrollDrag onChanged")
//
//                // if we're not in the middle opf
//                if activeGesture.isNone
//                    && value.translation.height.magnitude > SCROLL_THRESHOLD {
//                    print("scrollDrag onChanged: setting us to scroll")
//                    activeGesture = .scrolling
//                }
//
//                if activeGesture.isScroll {
//                    print("scrollDrag onChanged: updating per scroll")
//                    y = value.translation.height + previousY
//                }
//
//
//            }.onEnded { value in
//                print("scrollDrag onEnded")
//
//                if activeGesture.isScroll {
//                    print("scrollDrag onEnded: resetting scroll")
//                    activeGesture = .none
//                    previousY = y
//                }
//            }
//
        
        
        VStack {
            debugInfo
//            listBody.simultaneousGesture(scrollDrag)
            listBody
//            UIGestureOverlayView(content: listBody,
//                                 onScrollChanged: onScrollChanged,
//                                 onScrollEnded: onScrollEnded)
//                .simultaneousGesture(scrollDrag)
        }

    }
    
    
    var listBody: some View {
//        listView
        // need to provide a specific type,
        // so we can avoid
//        UIGestureOverlayView(content: listView,
        
        let scrollableList: ScrollableListView = ScrollableListView(
            onScrollChanged: onScrollChanged,
            onScrollEnded: onScrollEnded,
            activeSwipeId: $activeSwipeId,
            isBeingEdited: isBeingEdited,
            activeGesture: $activeGesture)
        
        return CustomListScrollGestureRecognizer(content: scrollableList,
                                    onScrollChanged: onScrollChanged,
                                    onScrollEnded: onScrollEnded)
//            .simultaneousGesture(scrollDrag)
            .frame(width: 1050, height: 1200)
        //            .offset(y: y - 400)
            .offset(y: y)
            .contentShape(Rectangle())
            .border(.red)
//            .simultaneousGesture(scrollDrag)
    }
    
//    var listView: some View {
//        ZStack {
//
//            SwipeView(id: 1,
//                      activeSwipeId: $activeSwipeId,
//                      itemY: 0,
//                      itemPreviousY: 0,
//                      isBeingEdited: isBeingEdited,
//                      activeGesture: $activeGesture)
//
//            SwipeView(id: 2,
//                      activeSwipeId: $activeSwipeId,
////                      y: 60,
////                      previousY: 60,
//                      itemY: 300,
//                      itemPreviousY: 300,
//                      isBeingEdited: isBeingEdited,
//                      activeGesture: $activeGesture)
//
////            SwipeView(id: 3,
////                      activeSwipeId: $activeSwipeId,
////                      y: 120,
////                      previousY: 120,
////                      isBeingEdited: isBeingEdited,
////                      activeGesture: $activeGesture)
////            SwipeView(id: 4,
////                      activeSwipeId: $activeSwipeId,
////                      y: 180,
////                      previousY: 180,
////                      isBeingEdited: isBeingEdited,
////                      activeGesture: $activeGesture)
////            SwipeView(id: 5,
////                      activeSwipeId: $activeSwipeId,
////                      y: 240,
////                      previousY: 240,
////                      isBeingEdited: isBeingEdited,
////                      activeGesture: $activeGesture)
//        }
//    }
}
