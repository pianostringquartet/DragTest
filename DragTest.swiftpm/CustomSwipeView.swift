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
        
    // 30% of view's width
    let RESTING_THRESHOLD: CGFloat = SWIPE_RECT_WIDTH / 3
    
    // 75% of view's width
    let DEFAULT_ACTION_THRESHOLD: CGFloat = SWIPE_RECT_WIDTH * 0.75
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 20) {
                Text("x: \(x)")
                Text("previousX: \(previousX)")
                Text("SWIPE_RECT_WIDTH - x: \(SWIPE_RECT_WIDTH - x)")
                Text("RESTING_THRESHOLD: \(RESTING_THRESHOLD)")
                Text("DEFAULT_ACTION_THRESHOLD: \(DEFAULT_ACTION_THRESHOLD)")
            }
            .offset(y: -100)
            .scaleEffect(1.5)
            
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
    
    var customSwipeItem: some View {
        
        let drag = DragGesture().onChanged { value in
            let xTrans = value.translation.width
            x = previousX - xTrans
            
            // never let us drag the list eastward beyond its frame
            if x < 0 {
                x = 0
            }
            
        }.onEnded { value in
            
            if atDefaultActionThreshold {
                x = DEFAULT_ACTION_THRESHOLD
                // dispatch default action here, which will cause view to rerender
                // without this given rect item
                print("TODO: delete item")
            }
            else if x >= RESTING_THRESHOLD {
                x = RESTING_THRESHOLD
            }
            // we didn't pull it out far enough -- set x = 0
            else {
                x = 0
            }
            
            previousX = x
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
        .frame(height: SWIPE_RECT_HEIGHT,
               alignment: .leading)
        
        // drag must be on outside, since we can drag
        // on an open menu
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
        
    // only size grows?
    // or also position
    var swipeMenu: some View {
        
        // the space available for the menu,
        // based on how we've dragged
        let menuSpace: CGFloat = x

        // space for a single option in the menu,
        // based on available menu space and number of options
        let numberofOptions: CGFloat = 3
        let optionSpace: CGFloat = menuSpace / numberofOptions
                       
        let redOption = Rectangle().fill(.red.opacity(SWIPE_OPTION_OPACITY))
            .overlay(alignment: .leading) {
                Button(role: .destructive) {
                    log("on delete...")
                } label: {
                    Image(systemName: "trash")
                }
                .foregroundColor(.white)
                .offset(x: optionSpace/2)
            }
        
        let tealOption = Rectangle().fill(.teal.opacity(SWIPE_OPTION_OPACITY))
            .overlay(alignment: .leading) {
                Button {
                    log("on toggle visibility...")
                } label: {
                    Image(systemName: "eye.slash")
                }
                .foregroundColor(.white)
                .offset(
                    x: (optionSpace * 2)/4
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
                .offset(
                    x: (optionSpace * 3)/6
                )
            }
    
        
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
//                .offset(x: SWIPE_RECT_WIDTH - optionSpace)
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