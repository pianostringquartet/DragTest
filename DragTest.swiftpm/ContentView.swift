import SwiftUI

let rectHeight: CGFloat = 100
let rectWidth: CGFloat = 400

// works!
func getMovedtoIndex(item: RectItem,
                     items: RectItems,
                     viewHeight: Int = 100) -> Int {
    
    let maxIndex = items.count - 1
    let maxY = maxIndex * viewHeight
    print("getMovedtoIndex: item.color: \(item.color)")
    print("getMovedtoIndex: maxY: \(maxY)")
    
    // no, needs to be by steps of 100
    // otherwise 0...800 will be 800 numbers
    
    let range = (0...maxY).reversed().filter { $0.isMultiple(of: viewHeight) }
    print("getMovedtoIndex: range: \(range)")
    
    print("getMovedtoIndex: item.location.y: \(item.location.y)")
    
    for threshold in range {
        if item.location.y > CGFloat(threshold) {
            print("getMovedtoIndex: found at threshold: \(threshold)")
            let i = threshold/viewHeight
            print("getMovedtoIndex: i: \(i)")
            return i
        }
    }
    
    // if didn't find anything, return the original index?
    let k = items.firstIndex { $0.id == item.id }!
    print("getMovedtoIndex: k: \(k)")
    return k
}


// used only during on drag;
func updatePositionsHelper(_ item: RectItem,
                           _ items: RectItems,
                           _ indicesToMove: [Int],
                           _ translationHeight: CGFloat) -> (RectItems, [Int]) {
    
    print("updatePositionsHelper called")
    var item = item
    var items = items
    var indicesToMove = indicesToMove
    
//    let originalItemIndex = items.firstIndex { $0.id == item.id }!
    
    print("updatePositionsHelper: item.location was: \(item.location)")
    print("updatePositionsHelper: item.previousLocation was: \(item.previousLocation)")
    
    // more, if this `item` has children
//    var indicesofItemsToMove: [Int] = [originalItemIndex]
    
    // always update the item's position first:
    item.location = updatePosition(
        translationHeight: translationHeight,
        location: item.previousLocation)
    
    print("updatePositionsHelper: item.location is now: \(item.location)")
    print("updatePositionsHelper: item.previousLocation is now: \(item.previousLocation)")
    
    let index: Int = items.firstIndex { $0.id == item.id }!
    items[index] = item
    indicesToMove.append(index)
    
//  ADD BACK LATER
    items.forEach { childItem in
        if let parentId = childItem.parentId,
//            parentId == item.id {
           parentId == item.id,
           // don't update the item again, since you already did that
           childItem.id != item.id {

            let (newItems, newIndices) = updatePositionsHelper(
                childItem,
                items,
                indicesToMove,
                translationHeight)

            // do I add all the newly updated items?
            // or do I have to re-insert at the index?
            //            items += newItems
            for newItem in newItems {
                let i = items.firstIndex { $0.id == newItem.id }!
                items[i] = newItem
            }

            indicesToMove = newIndices
        }
    }
    
    return (items, indicesToMove)
}


func maybeMoveIndices(_ items: RectItems,
                      indicesMoved: [Int],
                      to: Int,
                      originalIndex: Int) -> RectItems {
    
    if to != originalIndex {
        print("maybeMoveIndices: Will move...")
        var items = items
        
        /*
         listData.move(fromOffsets: IndexSet(integer: from),
                       toOffset: to > from ? to + 1 : to)
         */
        items.move(fromOffsets: IndexSet(indicesMoved),
                   toOffset: to > originalIndex ? to + 1 : to)
        
//        print("maybeMoveIndices: items after move: \(items)")
        
        items = setPositionsByIndices(items,
                                      isDragEnded: false)
        
        // print("maybeMoveIndices: items after position reset by indices: \(items)")
        
        return items
    } else {
        print("maybeMoveIndices: Will NOT move...")
        return items
    }
}


// maybe need to shift ALL items
func onDragged(_ item: RectItem, // assumes we've already
               _ translation: CGSize,
               _ items: [RectItem]) -> [RectItem] {
    
    print("onDragged called")
    var item = item
    var items = items
    
    print("onDragged: item was: \(item)")
    print("onDragged: items was: \(items)")
    
    let originalItemIndex = items.firstIndex { $0.id == item.id }!
        
    // ASSUMES GROUP IS OPEN
    // doesn't matter if group is closed? Because if it is, then we won't have even added those items to our
    let (newItems,
         indicesofItemsToMove) = updatePositionsHelper(item,
                                                       items,
                                                       [],
                                                       translation.height)
    
    items = newItems
    item = items[originalItemIndex] // update the `item` too!
    
    print("onDragged: newItems: \(newItems)")
    print("onDragged: new item: \(item)")
    print("onDragged: indicesofItemsToMove: \(indicesofItemsToMove)")
    
    // ^^ not just the item's immediate children, but ALL the children's children
        
    // eg [a, b, c] has max index of 2
    let calculatedIndex = getMovedtoIndex(item: item, items: items)

//    print("originalItemIndex: \(originalItemIndex)")
//    print("calculatedIndex: \(calculatedIndex)")

    return maybeMoveIndices(items,
                            indicesMoved: indicesofItemsToMove,
                            to: calculatedIndex,
                            originalIndex: originalItemIndex)
}


// when drag ends, we pop the views back into place via their indices
func onDragEnded(_ item: RectItem, _ items: [RectItem]) -> [RectItem] {
    print("onDragEnded called")
    let items = setPositionsByIndices(items, isDragEnded: true)
    print("onDragEnded: items is now: \(items)")
    return items
}

func updatePosition(translationHeight: CGFloat,
                    // usually: previousPosition
                    location: CGPoint) -> CGPoint {
    CGPoint(x: location.x,
            y: translationHeight + location.y)
}


typealias RectItems = [RectItem]

// position-less data to positioned data
// equivalent to: (LayerNodes -> [SidebarItem(position:)]
func itemsFromColors(_ colors: [Color],
                     _ viewHeight: Int = 100) -> RectItems {
    colors.enumerated().map { x in
        let color = x.element
        let index = x.offset
        let y = viewHeight * index
        
        return RectItem(id: index,
                        color: color,
                        location: CGPoint(x: 0, y: y))
    }
}

// for nested data
struct MyColor: Equatable {
    let color: Color
    var children: [MyColor] = []
}


let sampleColors0: [MyColor] = [
    MyColor(color: .red),
    MyColor(color: .blue),
    MyColor(color: .green)
]

let sampleColors1: [MyColor] = [
    MyColor(color: .red),
    MyColor(color: .blue, children: [
        MyColor(color: .black),
        MyColor(color: .brown)
    ]),
    MyColor(color: .green)
]

let sampleColors2: [MyColor] = [
    MyColor(color: .red),
    MyColor(color: .blue, children: [
        MyColor(color: .black),
        MyColor(color: .brown, children: [
            MyColor(color: .cyan),
            MyColor(color: .purple),
        ])
    ]),
    MyColor(color: .green)
]

let sampleColors3: [MyColor] = [
    MyColor(color: .red),
    MyColor(color: .blue, children: [
        MyColor(color: .black),
        MyColor(color: .brown, children: [
            MyColor(color: .cyan),
            MyColor(color: .purple, children: [
                MyColor(color: .orange),
                MyColor(color: .gray),
            ]),
        ])
    ]),
    MyColor(color: .green)
]


// Given a nested, ordered data structure, returns a flattened data structure with positions based on nesting + order
// for creating master list: RectItems with positions based on nesting etc.
func itemsFromColors(_ colors: [MyColor],
                     _ viewHeight: Int = 100) -> RectItems {
    
    // We increment upon each item (and each item's childItem)
    // hence we start at -1
    var currentHighestIndex = -1
    var items = RectItems()
    
    colors.forEach { color in
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
    print("itemsFromColors: items: \(items)")
    return items
}


// have to keep going through
func itemsFromColorHelper(_ color: MyColor,
                          _ currentHighestIndex: Int,
                          parentId: Int?,
                          nestingLevel: Int,
                          viewHeight: Int = 100) -> (Int, RectItems, Int) {
    
    print("itemsFromColorHelper: color: \(color)")
    var currentHighestIndex = currentHighestIndex
    var items = RectItems()
    var nestingLevel = nestingLevel
    
    currentHighestIndex += 1
    
    let item = RectItem(id: currentHighestIndex,
                        color: color.color,
                        location: CGPoint(x: (viewHeight/2) * nestingLevel,
                                          y: viewHeight * currentHighestIndex),
                        parentId: parentId)
    
    items.append(item)
    
    // if we're about to go down another level,
    // increment the nesting
    if !color.children.isEmpty {
        nestingLevel += 1
    }
    
    color.children.forEach { childColor in
        let (newIndex, newItems, newLevel) = itemsFromColorHelper(
            childColor,
            currentHighestIndex,
            parentId: item.id,
            nestingLevel: nestingLevel)
        
        print("itemsFromColorHelper: newIndex: \(newIndex)")
        print("itemsFromColorHelper: newItems: \(newItems)")
        print("itemsFromColorHelper: newLevel: \(newLevel)")
        
        currentHighestIndex = newIndex
        items += newItems
        nestingLevel = newLevel
    }
    
    return (currentHighestIndex, items, nestingLevel)
}


// eg given some existing items, with various positions,

// ie the order of the items now reflects what we want;
// and so we reset the items' positions to follow that order

// assumes we're dealing with a master list

// ie we've just REORDERED `items`,
// and now want to set their heights according to the REORDERED items;
// hence why we use `.enumerated`'s offsets, and not
func setPositionsByIndices(_ items: RectItems,
                           isDragEnded: Bool = false,
                           _ viewHeight: Int = 100) -> RectItems {

    
    items.enumerated().map { (offset, item) in
        // need to keep the level of nesting, which never changes when reseting positions
//        let newLocation = CGPoint(x: 0,
        var item = item
        let newY = CGFloat(offset * viewHeight)
        print("setPositionsByIndices: item: \(item)")
        print("setPositionsByIndices: newY: \(newY)")
        
        let newLocation = CGPoint(x: item.location.x,
//                                  y: CGFloat(offset * viewHeight))
                                  y: newY)
        item.location = newLocation
        if isDragEnded {
            print("setPositionsByIndices: drag ended, so resetting previous position")
            item.previousLocation = newLocation
        }
        return item
    }
}

//func setPositionsByIndices(_ items: RectItems,
//                           isDragEnded: Bool = false,
//                           _ viewHeight: Int = 100) -> RectItems {
//
//    // these are
//    items.map { item in
//        // need to keep the level of nesting, which never changes when reseting positions
//        let offset = item.id // id is also its masterList Index
//        var item = item
//        let newLocation = CGPoint(x: item.location.x,
//                                  y: CGFloat(offset * viewHeight))
//        item.location = newLocation
//        if isDragEnded {
//            print("setPositionsByIndices: drag ended, so resetting previous position")
//            item.previousLocation = newLocation
//        }
//        return item
//    }
//}



// ^^ for LayerNodes, we can't directly turn layer's position in ordered-dict into its position, since there might be intervening layer nodes that are part of a
// ... so will need something
// so will need some function that turns
// ... you will need

// ^^ actually, this should be okay? since we'll first generate the sidebar items in proper order and leveling/nested
// (based on layerNodes ordered-dict + groups dict)
// and then from there can generate what you need


struct ContentView: View {

    @State private var rectItems: RectItems = itemsFromColors(
//        [.red, .green, .blue, .purple, .orange],
//        sampleColors0,
//        sampleColors1,
//        sampleColors2,
        sampleColors3,
        Int(rectHeight))
    
    @State var isExpanded = false
    
    // the current id being dragged
    // nil when we're not dragging anything
    @State var current: Int? = nil
    
    var body: some View {
        
        ZStack {
            ForEach(rectItems, id: \.id) { (d: RectItem) in
                RectView2(item: d,
                          items: $rectItems,
                          current: $current)
                    .zIndex(Double(d.zIndex))
            } // ForEach
        } // ZStack
        .animation(.default)
        .offset(x: -200, y: -400)
    }
}


// CustomDG
//struct CustomDisclosureView: View {
//
//    let parent: RectItem
//    let children: RectItems
//
//    // ALL items, "the master list"; includes `parent` and `children`
//    @Binding var items: RectItems
//
//    @State var isExpanded = true
//
//    var body: some View {
//        ZStack {
//            RectView2(item: parent, items: $items)
//            if isExpanded {
//                ForEach(children, id: \.id) { (child: RectItem) in
//                    RectView2(item: child, items: $items)
//                }
//            } // isExpanded
//
//        } // ZStack
//        .animation(.default)
//    }
//}


struct RectItem: Identifiable, Equatable {
    let id: Int
    let color: Color
    var location: CGPoint
    var previousLocation: CGPoint
    var children: [RectItem] = []
    var zIndex: Int = 0
    
    // for converting items back into nested data
    var parentId: Int? = nil
    
    init(id: Int, color: Color, location: CGPoint, children: [RectItem] = [], parentId: Int? = nil) {
        self.id = id
        self.color = color
        self.location = location
        self.previousLocation = location
        self.children = children
        self.parentId = parentId
    }
}

extension Optional {
    var isDefined: Bool {
        self != nil
    }
}

struct RectView2: View {
    
    var item: RectItem
    @Binding var items: RectItems // all items
    @Binding var current: Int?
    
    var body: some View {
        Rectangle().fill(item.color)
//            .border((current.map { $0 == item.id } ?? false) ? .gray : .clear,
//                    width: 8)
            .border((current.map { $0 == item.id } ?? false) ? .white : .clear,
                    width: 16)
         
//            .overlay(Rect)
            .frame(width: rectWidth, height: rectHeight)
            .overlay(VStack {
                Text("Id: \(item.id)")
                Text("Parent?: \(item.parentId?.description ?? "None")")
            }.scaleEffect(1.4)
            )
            .foregroundColor(.white)
            .border(.orange)
//            .position(item.location)
//            .offset(CGSize(width: item.location.x,
        
            // while creating the items, can also create the indentation based not just on parentId.isDefined
            // but also on how deep the level of nesting is
//            .offset(CGSize(width: item.location.x + (item.parentId.isDefined ? 50 : 0),
            .offset(CGSize(width: item.location.x,
                           height: item.location.y))
//            .zIndex(Double(item.zIndex))
            .gesture(DragGesture()
                        .onChanged({ value in
                print("onChanged: \(item.id)")
                // done in onDragged
//                item.location = updatePosition(
//                    translationHeight: value.translation.height,
//                    location: item.previousLocation)
                current = item.id
                var item = item
                item.zIndex = 9999
                items = onDragged(item, // this dragged item
                                  value.translation, // drag data
                                  // ALL items
                                  items)
                
                // ^^ now that we've updated the location of the item,
                // we might need to also move the other items
                
                
            })
                        .onEnded({ _ in
                print("onEnded: \(item.id)")
                current = nil
                var item = item
                item.previousLocation = item.location
                item.zIndex = 0 // set to zero when drag ended
                let index = items.firstIndex { $0.id == item.id }!
                items[index] = item
                items = onDragEnded(item, items)
                
            })
            ) // gesture
    }
}
