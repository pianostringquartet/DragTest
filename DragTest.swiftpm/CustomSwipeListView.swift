//
//  CustomSwipeListView.swift
//  DragTest
//
//  Created by Christian J Clampitt on 3/30/22.
//

import Foundation
import SwiftUI

// `ActiveGesture?`
enum ActiveGesture: Equatable {
    case scrolling, // scrolling the entire list
         dragging, // drag or (long press + drag); on a single item
         swiping // swiping single item
    
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
    
    var isSwipe: Bool {
        switch self {
        case .swiping:
            return true
        default:
            return false
        }
    }
}


//let SCROLL_THRESHOLD: CGFloat = 8
//let SWIPE_THRESHOLD: CGFloat = 8

let SCROLL_THRESHOLD: CGFloat = 20
let SWIPE_THRESHOLD: CGFloat = 20

struct SwipeListView: View {
    
    @State var activeSwipeId: Int? = nil
    
    // position of list itself; scrolling etc.
    @State var y: CGFloat = 0
    @State var previousY: CGFloat = 0
    
    @State var isScrolling = false
    @State var canScroll = true
    @State var isBeingEdited = false
        
    @State var activeGesture: ActiveGesture? = nil
    
    var body: some View {

        let scrollDrag = DragGesture()
            .onChanged { value in
                print("scrollDrag onChanged")
                
                // if we're not in the middle opf
                if !activeGesture.isDefined
                    && value.translation.height.magnitude > SCROLL_THRESHOLD {
                    print("scrollDrag onChanged: setting us to scroll")
                    activeGesture = .scrolling
                }
                
                if activeGesture?.isScroll ?? false {
                    print("scrollDrag onChanged: updating per scroll")
                    y = value.translation.height + previousY
                }
                
                
            }.onEnded { value in
                print("scrollDrag onEnded")
                
                if activeGesture?.isScroll ?? false {
                    print("scrollDrag onEnded: resetting scroll")
                    activeGesture = nil
                    previousY = y
                }
            }
        
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text("list y: \(y)")
                    Text("list previousY: \(previousY)")
                }
                Rectangle().fill(.clear).frame(width: 250)
                Text("EDIT MODE?: \(isBeingEdited.description)").onTapGesture {
                    isBeingEdited.toggle()
                }
            }
            .scaleEffect(1.5)
            
            listBody.simultaneousGesture(scrollDrag)
        }

    }
    
    var listBody: some View {
        listView
            .frame(width: 1050, height: 1200)
            .offset(y: y - 400)
            .contentShape(Rectangle())
            .border(.red)
    }
    
    var listView: some View {
        ZStack {
            SwipeView(id: 1,
                      activeSwipeId: $activeSwipeId,
                      y: 0,
                      previousY: 0,
//                      isScrolling: $isScrolling,
//                      canScroll: $canScroll,
                      isBeingEdited: isBeingEdited,
                      activeGesture: $activeGesture)
            SwipeView(id: 2,
                      activeSwipeId: $activeSwipeId,
                      y: 500,
                      previousY: 500,
//                      y: 125,
//                      previousY: 125,
//                      isScrolling: $isScrolling,
//                      canScroll: $canScroll,
                      isBeingEdited: isBeingEdited,
                      activeGesture: $activeGesture)
            
//            SwipeView(id: 3,
//                      activeSwipeId: $activeSwipeId,
////                      y: 500,
////                      previousY: 500,
//                      y: 250,
//                      previousY: 250,
//                      isScrolling: $isScrolling,
//                      canScroll: $canScroll,
//                      isBeingEdited: isBeingEdited)
//
//
//            SwipeView(id: 4,
//                      activeSwipeId: $activeSwipeId,
////                      y: 500,
////                      previousY: 500,
//                      y: 375,
//                      previousY: 375,
//                      isScrolling: $isScrolling,
//                      canScroll: $canScroll,
//                      isBeingEdited: isBeingEdited)
            
        }
    }
    
    
    
}
