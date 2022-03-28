//
//  CustomSwipeView.swift
//  DragTest
//
//  Created by Christian J Clampitt on 3/28/22.
//

import SwiftUI


let SWIPE_RECT_WIDTH: CGFloat = 1000

//let SWIPE_RECT_HEIGHT: CGFloat = 500
let SWIPE_RECT_HEIGHT: CGFloat = 250

//let SWIPE_OPTION_OPACITY = 0.5
//let SWIPE_OPTION_OPACITY = 0.8
let SWIPE_OPTION_OPACITY = 0.95


struct SwipeView: View {
    
    // position of swipe menu
    @State var x: CGFloat = 0
    @State var previousX: CGFloat = 0
    
//    @State var x: CGFloat = 200
//    @State var previousX: CGFloat = 200
        
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
            }
            .offset(y: -50)
            .scaleEffect(1.1)
            
            customSwipeItem
        }
        
        // animate the automatic position changes of x
//        .animation(.default, value: x)
//        .animation(.easeInOut(duration: 1), value: x)
        
        // What's the real animation here?
        .animation(.linear(duration: 0.3), value: x)
    }
    
    var atDefaultActionThreshold: Bool {
        x >= DEFAULT_ACTION_THRESHOLD
    }
    
    var hasCrossedRestingThreshold: Bool {
        x >= RESTING_THRESHOLD
    }
    
    var customSwipeItem: some View {
        
//        let onDragChanged: OnSwipeDragChanged = { (value: DragGesture.Value) in
        let onDragChanged: OnSwipeDragChanged = { (translationWidth: CGFloat) in
            print("onDragChanged called")
//            let xTrans = value.translation.width
            
            x = previousX - translationWidth
            
            // never let us drag the list eastward beyond its frame
            if x < 0 {
                x = 0
            }
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
        Rectangle().fill(.indigo.opacity(0.3))
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
        
//        let defaultOptionPadding = optionSpace / 2
        
        // ie the default option padding
        var padding = optionSpace / 2
        
        // if we're not hidden, then we need to slightly pull to the left
        if x != 0 {
            padding -= 10
        }
        
        // should never let padding be less than 10 pixels
        if padding < 10 {
            return 10
        }
        
        return padding
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
