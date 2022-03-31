//
//  File.swift
//  DragTest
//
//  Created by Christian J Clampitt on 3/31/22.
//

import Foundation
import SwiftUI


struct DragListView: View {
    @State private var masterList = generateData()
    
    // the current id being dragged
    // nil when we're not dragging anything
//    @State var current: ItemId? = nil
    @State var current: BeingDraggedItem? = nil
    
    // nil = top level proposed
    // non-nil = deepested nested group possible to join,
    // based on dragged-item's current x position
    @State var proposedGroup: ProposedGroup? = nil
    
    // nil when not dragging
    // non-nil when dragging
    @State var cursorDrag: CursorDrag? = nil
    
    @State var y: CGFloat = 0
    @State var previousY: CGFloat = 0
    
    let nativeListWidth: CGFloat = 600
    
    var body: some View {
        list
//        nativeList
//            .frame(width: nativeListWidth)
            .frame(width: 400, height: 900)
        
//            .frame(width: 400)
            .animation(.default, value: masterList)
            .offset(x: -200, y: -500)

        
        // DISABLED FOR NOW
         
//            .offset(x: -200, y: y - 500)
//            .contentShape(Rectangle())
//            .border(.red)
//            .gesture(DragGesture()
//                        .onChanged({ value in
//                print("list drag onChanged")
//                y = value.translation.height + previousY
//            }).onEnded({ value in
//                print("list drag onEnded")
//                previousY = y
//            }))
    }
    
    var nativeList: some View {
        VStack {
            EditButton()
            HStack(spacing: 0) {
               Group { Text("0")
                Rectangle().fill(.clear).frame(width: 100)
                Text("1")
                Rectangle().fill(.clear).frame(width: 100)
                Text("2")}
                Rectangle().fill(.clear).frame(width: 100)
                Text("3")
                Rectangle().fill(.clear).frame(width: 100)
                Text("4")
                Rectangle().fill(.clear).frame(width: 100)
                Text("5")
            }.frame(width: nativeListWidth, height: 30, alignment: .leading)
            
            List {
                ForEach(masterList.items, id: \.id.value) { (d: RectItem) in
                    let isClosed = masterList.collapsedGroups.contains(d.id)
                                        
                        RectView2(item: d,
                                  masterList: $masterList,
                                  current: $current,
                                  proposedGroup: $proposedGroup,
                                  cursorDrag: $cursorDrag,
                                  isClosed: isClosed,
                                  useLocation: false)
                        
                            .swipeActions(edge: .trailing) {
                                // grey misc
                                // teal visibility (eye)
                                // red trash
                                // FROM LEFT TO RIGHT:
                                Button(role: .destructive) {
                                    log("on delete...")
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    log("on toggle visibility...")
                                } label: {
                                    Label("Hidden",
                                          systemImage: "eye.slash")
                                }.tint(.teal)
                                
                                Button {
                                    log("misc")
                                } label: {
                                    Label("Misc", systemImage: "ellipsis.circle")
                                }.tint(.gray)
                            }
                }.onMove { _, _ in
                    
                }.onDelete { _ in
                    
                }
            }
        }
    }
    
    var debugHelper: some View {
        VStack {
            Text("RESET").onTapGesture {
                masterList = generateData()
                current = nil
                proposedGroup = nil
            }.scaleEffect(1.5)
            
            let x = masterList.collapsedGroups.map { $0.id
            }.description
            Text("Collapsed: \(x)")
        }
        .offset(x: 500)
        
    }
    
    var list: some View {
        ZStack {
            logInView("ContentView: body: masterList.collapsedGroups: \(masterList.collapsedGroups)")
            debugHelper
            
            ForEach(masterList.items, id: \.id.value) { (d: RectItem) in
                
                let isClosed = masterList.collapsedGroups.contains(d.id)

                RectView2(item: d,
                          masterList: $masterList,
                          current: $current,
                          proposedGroup: $proposedGroup,
                          cursorDrag: $cursorDrag,
                          isClosed: isClosed)
                    .zIndex(Double(d.zIndex))
                
                
            } // ForEach
        } // ZStack
    }
    
}

