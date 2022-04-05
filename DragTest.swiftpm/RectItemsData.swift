//
//  File.swift
//  DragTest
//
//  Created by Christian J Clampitt on 3/31/22.
//

import Foundation
import SwiftUI

// // MARK: DATA

typealias ItemIds = [ItemId]

// if nil, then the 'proposed group' is top level
// and xIdentation = 0
struct ProposedGroup: Equatable {
    // ie aboveItem.parentId
    let parentId: ItemId //
    
    // better?: use `IndentationLevel`
    // ie aboveItem.location.x
    let xIndentation: CGFloat
    
    var indentationLevel: IndentationLevel {
        IndentationLevel.fromXLocation(x: xIndentation)
    }
}

struct IndentationLevel: Equatable {
    let value: Int
    
    init(_ value: Int) {
        self.value = value
    }
    
    func inc() -> IndentationLevel {
        IndentationLevel(self.value + 1)
    }
    
    func dec() -> IndentationLevel {
        IndentationLevel(self.value - 1)
    }
    
    static func fromXLocation(x: CGFloat) -> IndentationLevel {
        IndentationLevel(Int(x / CGFloat(INDENTATION_LEVEL)))
    }
    
    var toXLocation: CGFloat {
        CGFloat(self.value * INDENTATION_LEVEL)
    }
}

struct BeingDraggedItem: Equatable {
    // directly dragged
    var current: ItemId
    
    // dragged along as part of children etc.
    var draggedAlong: ItemIdSet
}

typealias RectItems = [RectItem]

// position-less data to positioned data
// equivalent to: (LayerNodes -> [SidebarItem(position:)]
struct MyColor: Equatable {
    let color: Color
    var children: [MyColor] = []
}

// parentId: [children in order]
typealias ExcludedGroups = [ItemId: RectItems]

typealias ItemIdSet = Set<ItemId>
typealias CollapsedGroups = ItemIdSet

struct MasterList: Equatable {
    var items: RectItems
    // the [parentId: child-ids] that are not currently shown
    var excludedGroups: ExcludedGroups
    
    // groups currently opened or closed;
    // an item's id is added when its group closed,
    // removed when its group opened;
    // NOTE: a supergroup parent closing/opening does NOT affect a subgroup's closed/open status
    var collapsedGroups: ItemIdSet
    
    init(_ items: RectItems,
         _ excludedGroups: ExcludedGroups = ExcludedGroups(),
         _ collapsedGroups: ItemIdSet = ItemIdSet()) {
        self.items = items
        self.excludedGroups = excludedGroups
        self.collapsedGroups = collapsedGroups
    }
    
    // ASSUMES ALL GROUPS OPEN
    static func fromColors(_ colors: [MyColor]) -> MasterList {
        let items = itemsFromColors(colors, VIEW_HEIGHT)
        let groups = ExcludedGroups()
        let collapsed = CollapsedGroups()
        return MasterList(items, groups, collapsed)
    }
    
    // we just add
    func appendToExcludedGroup(for key: ItemId,
                               _ newItem: RectItem) -> MasterList {
        var masterList = self
        var existing: RectItems = masterList.excludedGroups[key] ?? []
        
        existing.append(newItem)
        
        masterList.excludedGroups.updateValue(
            existing, forKey: key)
        
        return masterList
    }
}

struct ItemId: Identifiable, Equatable, Hashable {
    let value: Int
    
    init(_ value: Int) {
        self.value = value
    }
    
    var id: Int {
        value
    }
}

extension ItemId: CustomStringConvertible {
    var description: String {
        self.value.description
    }
}


struct RectItem: Equatable {
    //struct RectItem: Identifiable, Equatable {
    //    let id: Int
    let id: ItemId
    let color: Color
    
    // CGPoints
    var location: CGPoint
    var previousLocation: CGPoint
    
    var children: [RectItem] = []
    var zIndex: Int = 0
    
    // for converting items back into nested data
    var parentId: ItemId? = nil
    
    // is this item the parent for others?
    let isGroup: Bool
   
    init(id: ItemId,
         color: Color, location: CGPoint, children: [RectItem] = [], parentId: ItemId? = nil,
         isGroup: Bool) {
        self.id = id
        self.color = color
        self.location = location
        self.previousLocation = location
        self.children = children
        self.parentId = parentId
        self.isGroup = isGroup
    }
    
    // this item's index
    func itemIndex(_ items: RectItems) -> Int {
        // does "firstIndex(of: self) vs. of $0.id == thisItem.id matter?
        //        items.firstIndex(of: self)!
        items.firstIndex { $0.id == self.id }!
    }
    
    // better?: use previousLocation.x,
    // so that we can use an item's original indentation level while dragging,
    // and then its only in onDragEnded, at the end of snapDescendants,
    // that we update previousLocation
    var indentationLevel: IndentationLevel {
//        IndentationLevel.fromXLocation(x: self.location.x)
        IndentationLevel.fromXLocation(x: self.previousLocation.x)
    }
}


// // MARK: FUNCTIONS

// Given a nested, ordered data structure, returns a flattened data structure with positions based on nesting + order
// for creating master list: RectItems with positions based on nesting etc.
func itemsFromColors(_ colors: [MyColor],
                     _ viewHeight: Int = VIEW_HEIGHT) -> RectItems {
    
    // We increment upon each item (and each item's childItem)
    // hence we start at -1
    var currentHighestIndex = -1
    var items = RectItems()
    
    colors.forEach { color in
        
//        log("itemsFromColors: color: \(color)")
        
        let (newIndex, newItems, _) = itemsFromColorHelper(
            color,
            currentHighestIndex,
            // nil when at top level
            parentId: nil,
            // 0 when at top
            nestingLevel: 0)
        
        currentHighestIndex = newIndex
        items += newItems
    }
//    print("itemsFromColors: items: \(items)")
    return items
}

// needs to be able to handle a case where we've gone eg one-less in nesting,
// and then re-nest, etc.
func itemsFromColorHelper(_ color: MyColor,
                          _ currentHighestIndex: Int,
                          parentId: ItemId?,
                          nestingLevel: Int,
                          viewHeight: Int = VIEW_HEIGHT) -> (Int, RectItems, Int) {
    
//    log("itemsFromColorHelper: color: \(color)")
//    log("itemsFromColorHelper: nestingLevel at start: \(nestingLevel)")
    
    var currentHighestIndex = currentHighestIndex
    var items = RectItems()
    var nestingLevel = nestingLevel
    
    currentHighestIndex += 1
    
    // if MyColor has children at the creation,
    // then it is a group
    let hasChildren = !color.children.isEmpty
    
    let item = RectItem(
        id: ItemId(currentHighestIndex),
        color: color.color,
        location: CGPoint(x: (viewHeight/2) * nestingLevel,
                          y: viewHeight * currentHighestIndex),
        parentId: parentId,
        isGroup: hasChildren)
    
    items.append(item)
    
    // if there are no children for this color, then
    // nesting level stays the same?
    // how do we 'crawl back out of' a group?
    
//    if color.children.isEmpty {
    if !hasChildren {
        log("No children, so returning")
        return (currentHighestIndex, items, nestingLevel)
    }
    
    // if we're about to go down another level,
    // increment the nesting
//    if !color.children.isEmpty {
    if hasChildren {
        nestingLevel += 1
    }
//    log("itemsFromColorHelper: nestingLevel prepped for children: \(nestingLevel)")
    // ^^ what happens if we GO OUT of a nesting level?
    
    color.children.forEach { childColor in
        let (newIndex, newItems, newLevel) = itemsFromColorHelper(
            childColor,
            currentHighestIndex,
            parentId: item.id,
            nestingLevel: nestingLevel)
        
//        log("itemsFromColorHelper: newIndex: \(newIndex)")
//        log("itemsFromColorHelper: newItems: \(newItems)")
//        log("itemsFromColorHelper: newLevel: \(newLevel)")
        
        currentHighestIndex = newIndex
        items += newItems
        nestingLevel = newLevel
    }
    // maybe, eg, while we're looking through the children,
    // we have an increased nesting level,
    // but when we're done with the
//    log("Done with children for \(color), so decrementing nestingLevel")
    nestingLevel -= 1
    log("itemsFromColorHelper: nestingLevel after children: \(nestingLevel)")
    
    return (currentHighestIndex, items, nestingLevel)
}

func getDescendants(_ parentItem: RectItem,
                    //    _ parentXLocation: CGFloat,
                    _ items: RectItems) -> RectItems {
    // suppose you had two nested groups
    // separated
    // this could potentially
    // Suppose:
    // A
//    log("getDescendants: parentItem: \(parentItem)")
//    log("getDescendants: parentItem.location.x: \(parentItem.location.x)")
    //    items.filter { $0.location.x > parentXLocation }

    var descendants = RectItems()

    // not all items, but rather only items below!
    let itemsBelow = getItemsBelow(parentItem, items)
//    log("getDescendants: itemsBelow: \(itemsBelow)")

    //    for item in items {
    for item in itemsBelow {
//        log("itemBelow: \(item.id), \(item.location.x)")
        // if you encounter an item at or west of the parentXLocation,
        // then you've finished the parent's nested groups
        if item.location.x <= parentItem.location.x {
//            log("getDescendants: exiting early")
//            log("getDescendants: early exit: descendants: \(descendants)")
            return descendants
        }
        // ^^ possibly the parentItem location is incorrect in some cases when moving a group ?
        // ie item was east of parentXLocation

        // ^^ this is also incorrect when eg

        else {
            descendants.append(item)
        }
    }
//    log("getDescendants: returning: descendants: \(descendants)")
    return descendants
}




// // MARK: SAMPLE DATA

let sampleColors0: [MyColor] = [
    MyColor(color: .red),
    MyColor(color: .blue),
    MyColor(color: .green)
]

//let sampleColors1: [MyColor] = [
//    MyColor(color: .red),
//    MyColor(color: .blue, children: [
//        MyColor(color: .black),
//        MyColor(color: .brown)
//    ]),
//    MyColor(color: .green)
//]

//let sampleColors1: [MyColor] = [
////    MyColor(color: .red),
//    MyColor(color: .blue, children: [
//        MyColor(color: .black),
////        MyColor(color: .brown)
//    ]),
//    MyColor(color: .green)
//]


//let sampleColors1: [MyColor] = [
//    MyColor(color: .red),
//    MyColor(color: .blue, children: [
//        MyColor(color: .black),
//        MyColor(color: .brown)
//    ]),
//    MyColor(color: .green),
//    MyColor(color: .yellow)
//]

let sampleColors1: [MyColor] = [
    MyColor(color: .blue, children: [
        MyColor(color: .black),
    ])
]

let sampleColors2: [MyColor] = [
    MyColor(color: .red),
    MyColor(color: .blue, children: [
        MyColor(color: .black),
        MyColor(color: .brown, children: [
            MyColor(color: .cyan),
            //            MyColor(color: .purple),
        ])
    ]),
    MyColor(color: .green),
    //    MyColor(color: .yellow)
]

//let sampleColors3: [MyColor] = [
//    MyColor(color: .red),
//    MyColor(color: .blue, children: [
//        MyColor(color: .black),
//        MyColor(color: .brown, children: [
//            MyColor(color: .cyan),
//            MyColor(color: .purple, children: [
//                MyColor(color: .orange),
//                MyColor(color: .gray),
//            ]),
//        ])
//    ]),
//    MyColor(color: .green)
//]

let sampleColors3: [MyColor] = [
    MyColor(color: .red),
//    MyColor(color: .blue, children: [
//        MyColor(color: .black),
//        MyColor(color: .orange),
//    ]),
    MyColor(color: .brown, children: [
        MyColor(color: .cyan),
        MyColor(color: .gray),
    ]),
    MyColor(color: .green)
]

//let sampleColors4: [MyColor] = [
//    MyColor(color: .red),
//    MyColor(color: .blue, children: [
////        MyColor(color: .black),
//        MyColor(color: .brown, children: [
////            MyColor(color: .cyan),
//            MyColor(color: .purple)
//
//        ]),
//        MyColor(color: .indigo, children: [
////            MyColor(color: .orange),
//            MyColor(color: .gray),
//        ]),
//    ]),
//    MyColor(color: .green),
////    MyColor(color: .yellow)
//]

// repros a bug on main app...
let sampleColors4: [MyColor] = [
    MyColor(color: .red),
    MyColor(color: .black, children: [
        MyColor(color: .cyan),
    ]),
    MyColor(color: .blue, children: [
        MyColor(color: .brown, children: [
            MyColor(color: .purple)
        ]),
        MyColor(color: .indigo, children: [
            MyColor(color: .gray),
        ]),
    ]),
    MyColor(color: .green),
]


//let sampleColors4: [MyColor] = [
//    MyColor(color: .red),
//    MyColor(color: .blue, children: [
//
//        MyColor(color: .black),
//        MyColor(color: .indigo),
//
//        MyColor(color: .brown, children: [
//            MyColor(color: .cyan),
//            MyColor(color: .orange),
//        ]),
//    ]),
//    MyColor(color: .green),
//    MyColor(color: .yellow)
//]

func generateData() -> MasterList {
    MasterList.fromColors(
//        sampleColors0
//        sampleColors1
//        sampleColors2
//        sampleColors3
        sampleColors4
    )
}

