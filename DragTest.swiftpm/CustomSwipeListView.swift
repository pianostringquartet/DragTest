//
//  CustomSwipeListView.swift
//  DragTest
//
//  Created by Christian J Clampitt on 3/30/22.
//

import Foundation
import SwiftUI


let SCROLL_THRESHOLD: CGFloat = 8


struct SwipeListView: View {
    
    @State var activeSwipeId: Int? = nil
    
    @State var y: CGFloat = 0
    @State var previousY: CGFloat = 0
    
    
    @State var isScrolling = false
    @State var canScroll = true
    @State var isBeingEdited = false
        

    var body: some View {

        let scrollDrag = DragGesture()
            .onChanged{ value in
                print("list drag onChanged")
                
                // if we're starting with a
                
//                // if we're not at
//                if value.translation.height.magnitude < SCROLL_THRESHOLD {
//                    isScrolling = false
//                    return
//                }
                
                if canScroll && value.translation.height.magnitude < SCROLL_THRESHOLD {
                    isScrolling = false
                    return
                }
                
                // ^^ but how to add this back then?
                
                if canScroll {
                    y = value.translation.height + previousY
                    isScrolling = true
                }
            }.onEnded { value in
                print("list drag onEnded")
                
                // always set this false?
                isScrolling = false
                
                if canScroll {
                    previousY = y
                    isScrolling = false
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
                      isScrolling: $isScrolling,
                      canScroll: $canScroll,
                      isBeingEdited: isBeingEdited)
            SwipeView(id: 2,
                      activeSwipeId: $activeSwipeId,
                      y: 500,
                      previousY: 500,
//                      y: 125,
//                      previousY: 125,
                      isScrolling: $isScrolling,
                      canScroll: $canScroll,
                      isBeingEdited: isBeingEdited)
            
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
