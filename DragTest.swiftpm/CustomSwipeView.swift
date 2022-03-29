//
//  CustomSwipeView.swift
//  DragTest
//
//  Created by Christian J Clampitt on 3/28/22.
//

import SwiftUI

// will be CustomListItemView's width
let SWIPE_RECT_WIDTH: CGFloat = 1000

// will be CustomListItemView's height
//let SWIPE_RECT_HEIGHT: CGFloat = 500
let SWIPE_RECT_HEIGHT: CGFloat = 250

//let SWIPE_OPTION_OPACITY = 0.5
//let SWIPE_OPTION_OPACITY = 0.8
let SWIPE_OPTION_OPACITY: CGFloat = 1


struct SwipeListView: View {
    
    @State var activeSwipeId: Int? = nil
    
    var body: some View {
        VStack(spacing: 60) {
            SwipeView(id: 1, activeSwipeId: $activeSwipeId)
            SwipeView(id: 2, activeSwipeId: $activeSwipeId)
        }
    }
    
}


struct SwipeView: View {
    
    // position of swipe menu
    @State var x: CGFloat = 0
    @State var previousX: CGFloat = 0
    
//    @State var x: CGFloat = 200
//    @State var previousX: CGFloat = 200
        
    let id: Int
    
    @Binding var activeSwipeId: Int?
    
    // 30% of view's width
//    let RESTING_THRESHOLD: CGFloat = SWIPE_RECT_WIDTH / 3
    let RESTING_THRESHOLD: CGFloat = SWIPE_RECT_WIDTH * 0.2
    let RESTING_THRESHOLD_POSITION: CGFloat = SWIPE_RECT_WIDTH * 0.3
    
    // 75% of view's width
    let DEFAULT_ACTION_THRESHOLD: CGFloat = SWIPE_RECT_WIDTH * 0.75
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 5) {
                Text("x: \(x)")
                Text("previousX: \(previousX)")
                Text("SWIPE_RECT_WIDTH - x: \(SWIPE_RECT_WIDTH - x)")
                Text("RESTING_THRESHOLD: \(RESTING_THRESHOLD)")
                Text("RESTING_THRESHOLD_POSITION: \(RESTING_THRESHOLD_POSITION)")
                Text("DEFAULT_ACTION_THRESHOLD: \(DEFAULT_ACTION_THRESHOLD)")
                Text("optionSpace: \(optionSpace)")
                Text("optionPadding: \(optionPadding)")
            }
//            .offset(y: -50)
            .scaleEffect(1.1)
            
            customSwipeItem
        }
        // What's the real animation here?
        .animation(.linear(duration: 0.3), value: x)
        .onChange(of: activeSwipeId) { newValue in
            x = 0
            previousX = 0
        }
    }
    
    var atDefaultActionThreshold: Bool {
        x >= DEFAULT_ACTION_THRESHOLD
    }
    
    var hasCrossedRestingThreshold: Bool {
        x >= RESTING_THRESHOLD
    }
    
    var customSwipeItem: some View {
        
        let onDragChanged: OnSwipeDragChanged = { (translationWidth: CGFloat) in
            print("onDragChanged called")
            
            x = previousX - translationWidth
            
            // never let us drag the list eastward beyond its frame
            if x < 0 {
                x = 0
            }
            
            activeSwipeId = id
        }
        
        let onDragEnded: OnSwipeDragEnded = {
            print("onDragEnded called")
            if atDefaultActionThreshold {
                // Don't need to change x position here,
                // since redOption's offset handles that.
                                
                // dispatch default action here, which will cause view to rerender
                // without this given rect item
                print("TODO: delete item")
            }
            else if hasCrossedRestingThreshold {
                x = RESTING_THRESHOLD_POSITION
            }
            // we didn't pull it out far enough -- set x = 0
            else {
                x = 0
            }
            previousX = x
            activeSwipeId = id
        }
        
        
        let drag = DragGesture().onChanged { value in
//            log("DragGesture: onChanged")
            onDragChanged(value.translation.width)
        }.onEnded { value in
//            log("DragGesture: onEnded")
            onDragEnded()
        }
                
        return ZStack(alignment: .leading) {
            rect
            // size decreases as menu takes up more space
                .frame(width: SWIPE_RECT_WIDTH - x)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            swipeMenu
                .clipShape(RoundedRectangle(cornerRadius: 16))
            // constant:
                .frame(width: SWIPE_RECT_WIDTH)
            
            // create slight space between item and menu,
            // and edge of listView
                .padding([.leading, .trailing],
                         menuPadding)
        }
        
        // menu and item have same height;
        // but different widths
        .frame(height: SWIPE_RECT_HEIGHT, alignment: .leading)
        
        // overlay UIKit GestureRecognizer for 2-finger trackpad panning
        .overlay(SwipeGestureRecognizerView(
            onDragChanged: onDragChanged,
            onDragEnded: onDragEnded))
                
        // drag must be on outside, since we can drag
        // on an open menu;
        // must come AFTER UIKit GestureRecognizer
        .gesture(drag)
    }
    
    var menuPadding: CGFloat {
        // if we're at default action threshold,
        // or we've not dragged at all,
        // then no padding..
        if atDefaultActionThreshold || x == 0 {
            return 0
        }
        return 10
    }
    
    // ie the item
    var rect: some View {
        Rectangle().fill(.indigo.opacity(0.3)).overlay {
            Text("id: \(id)")
        }
    }
        
    var optionSpace: CGFloat {
        
        // the space available for the menu,
        // based on how we've dragged
        let menuSpace: CGFloat = x
        
        // space for a single option in the menu,
        // based on available menu space and number of options
        let numberofOptions: CGFloat = 3
        //        let optionSpace: CGFloat = menuSpace / numberofOptions
        return menuSpace / numberofOptions
    }
    
    var optionPadding: CGFloat {
        
        let tenPercentMargin = optionSpace * 0.1
        let minimum = tenPercentMargin < 10 ? 10 : tenPercentMargin
                
        // If we're at the resting position, or moving eastward (closing menu),
        // icon should be centered.
        if x <= RESTING_THRESHOLD_POSITION {
            let defaultOptionPadding = (optionSpace / 2) - 10
            // Always have at least some minimum padding;
            if defaultOptionPadding < minimum {
                return minimum
            }
            return defaultOptionPadding
        }
        else {
            // As we move away from resting, we don't want to
            // immediately jump from a eg 50% margin to a 10% margin;
            // so we taper it.
            let diff: CGFloat = RESTING_THRESHOLD_POSITION - x
            
            // As diff increases, padding decreases.
            let k = diff * 0.05
            let space = optionSpace / (2 - k)
            if space < minimum {
                return minimum
            }
            return space
        }
    }
    
    var swipeMenu: some View {
        
        let redOption = Rectangle().fill(.red.opacity(SWIPE_OPTION_OPACITY))
            .overlay(alignment: .leading) {
                Button(role: .destructive) {
                    log("on delete...")
                } label: {
                    Image(systemName: "trash")
                }
                .foregroundColor(.white)
                
                .padding(
                    [.leading],
                    atDefaultActionThreshold ? 60 : optionPadding
                )
            }
        
        let tealOption = Rectangle().fill(.teal.opacity(SWIPE_OPTION_OPACITY))
            .overlay(alignment: .leading) {
                Button {
                    log("on toggle visibility...")
                } label: {
                    Image(systemName: "eye.slash")
                }
                .foregroundColor(.white)
                .padding(
                    [.leading],
                    optionPadding
                )
            }
        
        let greyOption = Rectangle().fill(.gray.opacity(SWIPE_OPTION_OPACITY))
            .overlay(alignment: .leading) {
                Button {
                    log("on misc...")
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .foregroundColor(.white)
                .padding(
                    [.leading],
                    optionPadding
                )
            }
    
        
        // should be 0 when at default-action-threshod
        let redOffset: CGFloat = atDefaultActionThreshold
            ? 0
            : (SWIPE_RECT_WIDTH - optionSpace)
        
        return ZStack {
            
            greyOption.zIndex(-2)
            
            // TODO: Why must place corner radius here, before .offset,
            // to get the proper edge-rounding?
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .offset(x: SWIPE_RECT_WIDTH - (optionSpace * 3))
            
            tealOption.zIndex(-1)
                .offset(x: SWIPE_RECT_WIDTH - (optionSpace * 2))
            
            redOption
                .offset(x: redOffset)
        }
    }
}


//struct CustomSwipeView: View {
//    var body: some View {
//        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
//    }
//}
//
//struct CustomSwipeView_Previews: PreviewProvider {
//    static var previews: some View {
//        CustomSwipeView()
//    }
//}
