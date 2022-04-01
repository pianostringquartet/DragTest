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

//let SWIPE_RECT_HEIGHT: CGFloat = 250
let SWIPE_RECT_HEIGHT: CGFloat = 100
//let SWIPE_RECT_HEIGHT: CGFloat = 37

let SWIPE_OPTION_OPACITY: CGFloat = 1

let SWIPE_FULL_CORNER_RADIUS: CGFloat = 8


struct SwipeView: View {
    
    // position of swipe menu
    @State var swipeX: CGFloat = 0
    @State var swipePreviousX: CGFloat = 0
            
    let id: Int
    
    @Binding var activeSwipeId: Int?
    
    let RESTING_THRESHOLD: CGFloat = SWIPE_RECT_WIDTH * 0.2
    let RESTING_THRESHOLD_POSITION: CGFloat = SWIPE_RECT_WIDTH * 0.3
    
    // 75% of view's width
    let DEFAULT_ACTION_THRESHOLD: CGFloat = SWIPE_RECT_WIDTH * 0.75
    
    // position of item-view itself
    @State var itemY: CGFloat
    @State var itemPreviousY: CGFloat
        
    let isBeingEdited: Bool
    
    @Binding var activeGesture: ActiveGesture
    
    // need to pass these down to item's UIKit GestureHandler
    let onScrollChanged: OnDragChangedHandler
    let onScrollEnded: OnDragEndedHandler
    
    var body: some View {

        ZStack {
            debugInfo.offset(y: -110)
            customSwipeItem
        }
        
        // Must come BEFORE `y-offset` (height-positioning of item)
        .overlay(CustomListItemGestureRecognizerView(
            onItemSwipeChanged: itemSwipeChangedGesture,
            onItemSwipeEnded: itemSwipeEndedGesture,
            onItemDragChanged: itemDragChangedGesture,
            onItemDragEnded: itemDragEndedGesture,
            onScrollChanged: onScrollChanged,
            onScrollEnded: onScrollEnded))

//        .border(.red)
        .offset(y: itemY)
//        .border(.green)

        // Must come AFTER `y-offset` (height-positioning of item)
//        .simultaneousGesture(swipeDragGesture)
        // ^^ handle this in the same UIKit GR as
        
        .simultaneousGesture(longPressDragGesture)
                
        // What's the real animation here?
        .animation(.linear(duration: 0.3), value: swipeX)
        
        // if we swiped on another item,
        // reset this item's swipe
        .onChange(of: activeSwipeId) { newValue in
            swipeX = 0
            swipePreviousX = 0
        }
        .onChange(of: activeGesture) { (newValue) in
            switch newValue {
            // scrolling or dragging resets swipe-menu
            case .scrolling, .dragging:
                swipeX = 0
                swipePreviousX = 0
            default:
                return
            }
        }
    }
    
    var itemDragChangedGesture: OnDragChangedHandler  {
        return { (translationHeight: CGFloat) in
            // add this additional check, for when it's being used
            // not in combination with long-press
            
//            if activeGesture.isNone
            
            print("itemDragChangedGesture called")
            itemY = translationHeight + itemPreviousY
            activeGesture = .dragging(id)
        }
    }
    
    var itemDragEndedGesture: OnDragEndedHandler  {
        return {
            print("itemDragEndedGesture called")
            itemPreviousY = itemY
            activeGesture = .none
        }
    }
    
    var longPressDragGesture: LongPressAndDragGestureType {
        
        let longPress = LongPressGesture(minimumDuration: 0.5).onEnded { _ in
            print("longPress onChanged")
            activeGesture = .dragging(id)
        }
        
        let itemDrag = DragGesture(minimumDistance: 0)
            .onChanged { value in
                print("itemDrag onChanged")
                itemDragChangedGesture(value.translation.height)
            }.onEnded { value in
                print("itemDrag onEnded")
                itemDragEndedGesture()
            }

        return longPress.sequenced(before: itemDrag)
    }
    
    var itemSwipeChangedGesture: OnDragChangedHandler {
        let onSwipeChanged: OnDragChangedHandler = { (translationWidth: CGFloat) in
            
            print("itemSwipeChangedGesture called")
                        
            // if we have no active gesture,
            // and we met the swipe threshold,
            // then we can begin swiping
            if activeGesture.isNone
                && translationWidth.magnitude > SWIPE_THRESHOLD {
                print("itemSwipeChangedGesture: setting us to swipe")
                
                activeGesture = .swiping
            }
            
            if activeGesture.isSwipe {
                print("itemSwipeChangedGesture: updating per swipe")
                
                swipeX = swipePreviousX - translationWidth
                
                // never let us drag the list eastward beyond its frame
                if swipeX < 0 {
                    swipeX = 0
                }
                
                activeSwipeId = id
            }
        }
        
        return onSwipeChanged
    }
    
    var itemSwipeEndedGesture: OnDragEndedHandler {
        let onSwipeEnded: OnDragEndedHandler = {
            print("itemSwipeEndedGesture called")
            
            // if we had been swiping,
            // then we resset activeGesture
            if activeGesture.isSwipe {
                print("itemSwipeEndedGesture onEnded: resetting swipe")
                activeGesture = .none
                
                if atDefaultActionThreshold {
                    // Don't need to change x position here,
                    // since redOption's offset handles that.
                    
                    // dispatch default action here, which will cause view to rerender
                    // without this given rect item
                    print("TODO: delete item")
                }
                else if hasCrossedRestingThreshold {
                    swipeX = RESTING_THRESHOLD_POSITION
                }
                // we didn't pull it out far enough -- set x = 0
                else {
                    swipeX = 0
                }
                swipePreviousX = swipeX
                activeSwipeId = id
            } // if active...
        }
        return onSwipeEnded
    }
    
    var swipeDragGesture: DragGestureType {
        
        let swipeDrag = DragGesture().onChanged { value in
            //            log("DragGesture: onChanged")
            itemSwipeChangedGesture(value.translation.width)
        }.onEnded { value in
            //            log("DragGesture: onEnded")
            itemSwipeEndedGesture()
        }
        
        return swipeDrag
    }
    
    var debugInfo: some View {
        VStack(spacing: 5) {
            Group {
                Text("x: \(swipeX)")
                Text("previousX: \(swipePreviousX)")
                Text("item y: \(itemY)")
                Text("item previousY: \(itemPreviousY)")
                
//                Text("SWIPE_RECT_WIDTH - x: \(SWIPE_RECT_WIDTH - x)")
//                Text("RESTING_THRESHOLD: \(RESTING_THRESHOLD)")
//                Text("RESTING_THRESHOLD_POSITION: \(RESTING_THRESHOLD_POSITION)")
//                Text("DEFAULT_ACTION_THRESHOLD: \(DEFAULT_ACTION_THRESHOLD)")
            }
            Group {
//                Text("optionSpace: \(optionSpace)")
//                Text("optionPadding: \(optionPadding)")
//                Text("swipeMenuCornerRadius: \(swipeMenuCornerRadius)")
//                Text("isScrolling: \(isScrolling.description)")
//                Text("canScroll: \(canScroll.description)")
//                Text("isDragging: \(isDragging.description)")
//                Text("canSwipe: \(canSwipe.description)")
                
//                Text("activeGesture: \(activeGesture)")
            }
        }
        .scaleEffect(1.2)
//        .scaleEffect(1.3)
    }
    
    var atDefaultActionThreshold: Bool {
        swipeX >= DEFAULT_ACTION_THRESHOLD
    }
    
    var hasCrossedRestingThreshold: Bool {
        swipeX >= RESTING_THRESHOLD
    }
        
    var customSwipeItem: some View {
        
        return ZStack(alignment: .leading) {
            rect
            // size decreases as menu takes up more space
                .frame(width: SWIPE_RECT_WIDTH - swipeX)
                .clipShape(RoundedRectangle(cornerRadius: SWIPE_FULL_CORNER_RADIUS))
            
            swipeMenu
                .clipShape(RoundedRectangle(cornerRadius: swipeMenuCornerRadius))
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
        
//        .overlay(SwipeGestureRecognizerView(
//            onDragChanged: onSwipeChanged,
//            onDragEnded: onSwipeEnded))
//
//        // drag must be on outside, since we can drag
//        // on an open menu;
//        // must come AFTER UIKit GestureRecognizer
////        .gesture(swipeDrag)
//        .simultaneousGesture(swipeDrag)
        
        // ^^ should this be a simultaneous?
        
        // This must be placed here, inside
//        .overlay(SwipeGestureRecognizerView(
//            onDragChanged: onSwipeChangedGesture,
//            onDragEnded: onSwipeEndedGesture))
        
    }
    
    var menuPadding: CGFloat {
        // if we're at default action threshold,
        // or we've not dragged at all,
        // then no padding..
        if atDefaultActionThreshold || swipeX == 0 {
            return 0
        }
        // if we've started dragging,
        // then introduce slight padding
        else if swipeX < 10 {
            return swipeX
        }
        // eventually we reach full padding
        return 10
    }
    
    // ie the item
    var rect: some View {
        let dragging = activeGesture.dragId.map { $0 == id } ?? false
        let color: Color = dragging ? .green : .indigo
        
        return Rectangle().fill(color.opacity(0.3)).overlay {
            Text("id: \(id)")
        }
    }
        
    var optionSpace: CGFloat {
        
        // the space available for the menu,
        // based on how we've dragged
        let menuSpace: CGFloat = swipeX
        
        // space for a single option in the menu,
        // based on available menu space and number of options
        let numberofOptions: CGFloat = 3
        //        let optionSpace: CGFloat = menuSpace / numberofOptions
        return menuSpace / numberofOptions
    }
    
    // For proper alignment of icons
    var optionPadding: CGFloat {
                
        let tenPercentMargin = optionSpace * 0.1
        let minimum = tenPercentMargin < 10 ? 10 : tenPercentMargin
                
        // If we're at the resting position, or moving eastward (closing menu),
        // icon should be centered.
        if swipeX <= RESTING_THRESHOLD_POSITION {
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
            let diff: CGFloat = RESTING_THRESHOLD_POSITION - swipeX
            
            // As diff increases, padding decreases.
            let k = diff * 0.05
            let space = optionSpace / (2 - k)
            if space < minimum {
                return minimum
            }
            return space
        }
    }
    
    // decrease the corner radius on swipe menu as we get smaller;
    // note that item's corner radius DOES NOT change
    var swipeMenuCornerRadius: CGFloat {
        if optionSpace < 4 {
            return SWIPE_FULL_CORNER_RADIUS * 0.5
        }
        else if optionSpace < 8 {
            return SWIPE_FULL_CORNER_RADIUS * 0.8
        }
        else {
            // default
            return SWIPE_FULL_CORNER_RADIUS
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
                .clipShape(RoundedRectangle(cornerRadius: swipeMenuCornerRadius))
                .offset(x: SWIPE_RECT_WIDTH - (optionSpace * 3))
            
            tealOption.zIndex(-1)
                .offset(x: SWIPE_RECT_WIDTH - (optionSpace * 2))
            
            redOption
                .offset(x: redOffset)
        }
    }
}
