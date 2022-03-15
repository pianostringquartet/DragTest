import SwiftUI

let rectHeight: CGFloat = 100
let rectWidth: CGFloat = 400


// for safe indexing
extension Array {
    public subscript(safeIndex index: Int) -> Element? {
        guard index >= 0, index < endIndex else {
            return nil
        }

        return self[index]
    }
}



// if nil, then the 'proposed group' is top level
// and xIdentation = 0
struct ProposedGroup: Equatable {
    // ie aboveItem.parentId
    let parentId: ItemId //
    
    // ie aboveItem.location.x
    let xIndentation: CGFloat
}


typealias RectItems = [RectItem]

// position-less data to positioned data
// equivalent to: (LayerNodes -> [SidebarItem(position:)]

// for nested data
struct MyColor: Equatable {
    let color: Color
    var children: [MyColor] = []
}

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
//    print("itemsFromColors: items: \(items)")
    return items
}

// ie assumes we create all the groups OPEN?
// ASSUMES ALL GROUPS START OPEN
//func masterListFromColors(_ colors: [MyColor]) -> MasterList {
//    let items = itemsFromColors(colors, VIEW_HEIGHT)
////    let groups = buildGroupsFromItems(items)
//    let groups = ExcludedGroups()
//    return MasterList(items, groups)
//
//}

// not needed?
func buildGroupsFromItems(_ items: RectItems) -> ExcludedGroups {
    var groupsDict = ExcludedGroups()
    for item in items {
        // any items that have parentId = this item's id
        let children = items.filter { ($0.parentId ?? nil) == item.id }
        groupsDict.updateValue(children,
                               forKey: item.id)
    }
    return groupsDict
}


// have to keep going through
func itemsFromColorHelper(_ color: MyColor,
                          _ currentHighestIndex: Int,
                          parentId: ItemId?,
                          nestingLevel: Int,
                          viewHeight: Int = 100) -> (Int, RectItems, Int) {
    
//    print("itemsFromColorHelper: color: \(color)")
    var currentHighestIndex = currentHighestIndex
    var items = RectItems()
    var nestingLevel = nestingLevel
    
    currentHighestIndex += 1
    
    let item = RectItem(id: ItemId(currentHighestIndex),
//    let item = RectItem(id: color.color,
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
        
//        print("itemsFromColorHelper: newIndex: \(newIndex)")
//        print("itemsFromColorHelper: newItems: \(newItems)")
//        print("itemsFromColorHelper: newLevel: \(newLevel)")
        
        currentHighestIndex = newIndex
        items += newItems
        nestingLevel = newLevel
    }
    
    return (currentHighestIndex, items, nestingLevel)
}


// parentId: [children in order]
typealias ExcludedGroups = [ItemId: RectItems]
// ^^ needs to be full child, since needs to preserve color etc.;
// note that full child's location will be updated when adding back into `items` list

struct MasterList: Equatable {
    var items: RectItems
    // the [parentId: child-ids] that are not currently shown
    var excludedGroups: ExcludedGroups
    
    // groups currently shown
//    var visibleGroups: ItemGroups
    
    init(_ items: RectItems, _ groups: ExcludedGroups) {
        self.items = items
        self.excludedGroups = groups
    }
    
    // ASSUMES ALL GROUPS OPEN
    static func fromColors(_ colors: [MyColor]) -> MasterList {
        let items = itemsFromColors(colors, VIEW_HEIGHT)
    //    let groups = buildGroupsFromItems(items)
        let groups = ExcludedGroups()
        return MasterList(items, groups)
    }
    
    func appendToExcludedGroup(for key: ItemId, _ newItem: RectItem) -> MasterList {
        var masterList = self
        var existing: RectItems = masterList.excludedGroups[key] ?? []
        existing.append(newItem)
        masterList.excludedGroups.updateValue(existing, forKey: key)
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

struct RectItem: Equatable {
//struct RectItem: Identifiable, Equatable {
//    let id: Int
    let id: ItemId
    let color: Color
    var location: CGPoint
    var previousLocation: CGPoint
    var children: [RectItem] = []
    var zIndex: Int = 0
    
    // for converting items back into nested data
    var parentId: ItemId? = nil
    
    // true just when this item is part of a group
    // that has been closed;
    // can NEVER be `true` if parent
//    var isHidden = false
    
//    var isHidden: Bool {
//        get {
//            if self.isHidden && !parentId.isDefined {
//                fatalError()
//            }
//            return self.isHidden
//        }
//        set(value) {
//            self.isHidden = value
//        }
//    }
    
//    init(id: Int,
    init(id: ItemId,
         color: Color, location: CGPoint, children: [RectItem] = [], parentId: ItemId? = nil) {
        self.id = id
        self.color = color
        self.location = location
        self.previousLocation = location
        self.children = children
        self.parentId = parentId
//        self.isHidden = isHidden
    }
    
    // this item's index
    func itemIndex(_ items: RectItems) -> Int {
        // does "firstIndex(of: self) vs. of $0.id == thisItem.id matter?
//        items.firstIndex(of: self)!
        items.firstIndex { $0.id == self.id }!
    }
    
    var indentationLevel: IndentationLevel {
        IndentationLevel.fromXLocation(x: self.location.x)
    }
    
    
}

extension Optional {
    var isDefined: Bool {
        self != nil
    }
}



struct RectView2: View {
    
    var item: RectItem
//    @Binding var items: RectItems // all items
    @Binding var masterList: MasterList // all items + groups
    @Binding var current: ItemId?
    @Binding var proposedGroup: ProposedGroup?
    
    var body: some View {
        rectangle
//        if item.isHidden {
//            EmptyView()
//        } else {
//            rectangle
//        }
    }
    
//    var body: some View {
    var rectangle: some View {
        
        let isBeingDraggedColor: Color = (current.map { $0 == item.id } ?? false) ? .white : .clear
        
        let isProposedGroupColor: Color = (proposedGroup?.parentId == item.id) ? .white : .clear
        
        return Rectangle().fill(item.color)
            .border(isBeingDraggedColor, width: 16)
//            .border(isProposedGroupColor, width: 8)
            .overlay(isProposedGroupColor.opacity(0.8))
            .frame(width: rectWidth, height: rectHeight)
            .overlay(
                HStack {
                    VStack {
                        Text("Id: \(item.id.value)")
                        Text("Parent?: \(item.parentId?.value.description ?? "None")")
                    }
                    
                    if hasChildren(item.id, masterList) {
                        let isClosed = isGroupClosed(item.id, masterList)
                        Text("\(isClosed ? "OPEN" : "CLOSE")").offset(x: 40)
                            .onTapGesture {
                                log("onTap...")
                                if isClosed {
                                    masterList = groupOpened(openedId: item.id, masterList)
                                } else {
                                    masterList = groupClosed(closedId: item.id, masterList)
                                }
                                
                            }
                    }
                }
                    .scaleEffect(1.4)
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
                
                let (newItems, proposed) = onDragged(
                    item, // this dragged item
                    value.translation, // drag data
                    // ALL items
                    masterList.items)
                
                masterList.items = newItems
                proposedGroup = proposed
                
                // ^^ now that we've updated the location of the item,
                // we might need to also move the other items
                
                
            })
                        .onEnded({ _ in
                print("onEnded: \(item.id)")
                current = nil
                var item = item
                item.previousLocation = item.location
                item.zIndex = 0 // set to zero when drag ended
                
                let index = masterList.items.firstIndex { $0.id == item.id }!
                masterList.items[index] = item
                masterList.items = onDragEnded(
                    item,
                    masterList.items,
                    proposed: proposedGroup)
                
                // also reset the potentially highlighted group
                proposedGroup = nil
                
            })
            ) // gesture
    }
}


//func nonHiddenItemsOnly(_ items: RectItems) -> RectItems {
//    items.filter { !$0.isHidden }
//}

// instead of just toggling the bool, we do more now
//func hideChildren(closedParent: ItemId,
//                  _ items: RectItems) -> RectItems {
//    items.map { item in
//        var item = item
//        if item.parentId == closedParent {
//            item.isHidden = true
//            return item
//        }
//        return item
//    }
//}

typealias ItemIds = [ItemId]
typealias Items = RectItems
//
//func hideChildren(closedParent: ItemId,
//                  _ masterList: MasterList) -> MasterList {
//
//    var itemsWithoutChildren = masterList.items
//    var excludedChildren = Items()
//
//    // this doesn't work for nested groups,
//    // because nested group's child will have a different parent
//    for item in masterList.items {
//        if item.parentId == closedParent {
//            excludedChildren.append(item)
//            itemsWithoutChildren.removeAll { $0.id == item.id }
//        }
//    }
//
//    var masterList = masterList
//    masterList.excludedGroups.updateValue(excludedChildren, forKey: closedParent)
//    masterList.items = itemsWithoutChildren
//    return masterList
//}


let INDENTATION_LEVEL: Int = VIEW_HEIGHT / 2

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




// ie ALL the children, even if eg their parentId is not the same as closed parent id;
// ie any items below this parent with an indentation level GT parent's identation
// careful here; if you switched this to only use indentation level,
// then is places like this onDrag, where might have
func getDescendants(_ parentItem: RectItem,
//    _ parentXLocation: CGFloat,
                    _ items: RectItems) -> RectItems {
    // suppose you had two nested groups
    // separated
    // this could potentially
    // Suppose:
    // A
    
//    items.filter { $0.location.x > parentXLocation }
    
    var descendants = RectItems()
    
    // not all items, but rather only items below!
    let itemsBelow = getItemsBelow(parentItem, items)
    log("getDescendants: itemsBelow: \(itemsBelow)")
    
//    for item in items {
    for item in itemsBelow {
        // if you encounter an item at or west of the parentXLocation,
        // then you've finished the parent's nested groups
        if item.location.x <= parentItem.location.x {
            return descendants
        }
        // ie item was east of parentXLocation
        else {
            descendants.append(item)
        }
        
    }
    return descendants
}


// if "parent" does not have an iimte
// Better?: `!getDescendents.isEmpty`
func hasOpenChildren(_ item: RectItem, _ items: RectItems) -> Bool {
    
    let parentIndex = item.itemIndex(items)
    let nextChildIndex = parentIndex + 1
    
    if let child = items[safeIndex: nextChildIndex],
       let childParent = child.parentId,
       childParent == item.id {
        return true
    }
    return false
}


// only called if parent
func hideChildren(closedParentId: ItemId,
                  _ masterList: MasterList) -> MasterList {

    var masterList = masterList
    
    let closedParent = retrieveItem(closedParentId, masterList.items)
    
    // all the items below this parent, with indentation > parent's
    let descendants = getDescendants(closedParent, masterList.items)
            
    // starting: immediate parent will have closed parent's id
    var currentParent: ItemId = closedParentId
    
    // starting: immediate child of parent will have parent's indentation level + 1
    var currentDeepestIndentation = closedParent.indentationLevel.inc()
    
    for descendant in descendants {
        log("on descendant: \(descendant)")
        
        // if we ever have a descendant at the same,
        // or even further west, of the closedParent,
        // then we made a mistake!
        if descendant.indentationLevel.value <= closedParent.indentationLevel.value {
            fatalError()
        }
        
        // if this descendant is in the same nesting level,
        // just added it to
        if descendant.indentationLevel == currentDeepestIndentation {
            masterList = masterList.appendToExcludedGroup(
                for: currentParent, descendant)
        }
        // we either increased or decreased in indentation
        else {
            
            // if we changed indentation levels (whether east or west),
            // we should have a new parent
            currentParent = descendant.parentId!
            
            // ie we went deeper (farther east)
            if descendant.indentationLevel.value > currentDeepestIndentation.value {
                log("went east")
                currentDeepestIndentation = currentDeepestIndentation.inc()
            }
            // ie. we backed up (went one level west)
            // ie. descendant.indentationLevel.value < currentDeepestIndentation.value
            else {
                log("went west")
                currentDeepestIndentation = currentDeepestIndentation.dec()
            }
            
            // set the descendant AFTER we've updated the parent
            masterList = masterList.appendToExcludedGroup(
                for: currentParent, descendant)
        }
    }

    // finally, remove descendants from items list
    let descendentsIdSet: Set<ItemId> = Set(descendants.map(\.id))
    
    masterList.items.removeAll { descendentsIdSet.contains($0.id) }

    log("hideChildren: masterList is now: \(masterList)")
    
    return masterList
}


// retrieve children
// nil = parentId had no
// non-nil = returning children, plus removing the parentId entry from ExcludedGroups
func popExcludedChildren(parentId: ItemId,
                         _ masterList: MasterList) -> (RectItems, ExcludedGroups)? {

    if let excludedChildren = masterList.excludedGroups[parentId] {
        var groups = masterList.excludedGroups
        groups.removeValue(forKey: parentId)
        return (excludedChildren, groups)
    }
    return nil
}

//
//func crawl(_ parent: RectItem,
////           _ children: RectItems, // immediatge children of this parent
//           _ height: CGFloat, // height of item immediately above
//
//           // ALL items
//           _ masterList: MasterList) -> MasterList {
//
//    var masterList = masterList
//
//    if let (excludedChildren, updatedMaster) = popExcludedChildren(parentId: parent.id, masterList) {
//        masterList = updatedMaster
//        for child
//
//    }
//
//    for child in children {
//    }
//}

func setOpenedChildHeight(_ item: RectItem,
                          _ height: CGFloat) -> RectItem {
    var item = item
    // set height only; preserve indentation
    item.location = CGPoint(x: item.location.x, y: height)
    item.previousLocation = item.location
    return item
}

func unhideChildrenHelper(item: RectItem, // item that could be a parent or not
                          currentHighestIndex: Int, // starts: opened parent's index
                          currentHighestHeight: CGFloat, // starts: opened parent's height
                          _ masterList: MasterList,
                          isRoot: Bool) -> (MasterList, Int, CGFloat) {
    
    var masterList = masterList
    var currentHighestIndex = currentHighestIndex
    var currentHighestHeight = currentHighestHeight
    
    log("unhideChildrenHelper: item was: \(item.id), \(item.color)")
//    log("unhideChildrenHelper: currentHighestIndex was: \(currentHighestIndex)")
//    log("unhideChildrenHelper: currentHighestHeight was: \(currentHighestHeight)")
    
    // first, insert the item
    // then, recur on any children

    // insert item
    if !isRoot {
        let (updatedMaster,
             updatedHighestIndex,
             updatedHighestHeight) = insertUnhiddenItem(item: item,
                           currentHighestIndex: currentHighestIndex,
                           currentHighestHeight: currentHighestHeight,
                           masterList)
        
        masterList = updatedMaster
        currentHighestIndex = updatedHighestIndex
        currentHighestHeight = updatedHighestHeight
    } else {
        log("unhideChildrenHelper: had root item \(item.id), so will not add root item again")
    }
    
    // does this `item` have itemren of its own?
    // if so, recur
    if let (excludedChildren, updatedGroups) = popExcludedChildren(
        parentId: item.id, masterList) {
        
        log("unhideChildrenHelper: had children")
        
        masterList.excludedGroups = updatedGroups
                
        // excluded children must be handled in IN ORDER
        for child in excludedChildren {
            log("unhideChildrenHelper: on child \(child.id) of item \(item.id)")
            let (updatedMaster,
                 updatedHighestIndex,
                 updatedHighestHeight) = unhideChildrenHelper(
                    item: child,
                    currentHighestIndex: currentHighestIndex,
                    currentHighestHeight: currentHighestHeight,
                    masterList,
                    isRoot: false)
            
            masterList = updatedMaster
            currentHighestIndex = updatedHighestIndex
            currentHighestHeight = updatedHighestHeight
        }
    }
    
    return (masterList, currentHighestIndex, currentHighestHeight)
}


func insertUnhiddenItem(item: RectItem, // item that could be a parent or not
                        currentHighestIndex: Int, // starts: opened parent's index
                        currentHighestHeight: CGFloat, // starts: opened parent's height
                        _ masterList: MasterList) -> (MasterList, Int, CGFloat) {
    
//    log("unhideChildrenHelper: on child-less item \(item.id), color \(item.color)")
    
    log("insertUnhiddenItem: currentHighestIndex was: \(currentHighestIndex)")
    log("insertUnhiddenItem: currentHighestHeight was: \(currentHighestHeight)")
    
    var item = item
    var currentHighestIndex = currentHighestIndex
    var currentHighestHeight = currentHighestHeight
    var masterList = masterList
    
    // + 1 so inserted AFTER previous currentHighestIndex
    currentHighestIndex += 1
    currentHighestHeight += CGFloat(VIEW_HEIGHT)
    log("insertUnhiddenItem: currentHighestIndex is now: \(currentHighestIndex)")
    log("insertUnhiddenItem: currentHighestHeight is now: \(currentHighestHeight)")
    
    item = setOpenedChildHeight(item, currentHighestHeight)
      
    log("insertUnhiddenItem: masterList.items colors were: \(masterList.items.map(\.color))")
    
    masterList.items.insert(item, at: currentHighestIndex)
    
    log("insertUnhiddenItem: masterList.items colors are now: \(masterList.items.map(\.color))")
    
    return (masterList, currentHighestIndex, currentHighestHeight)
}


// returns (masterList, lastIndexOfAddedReAdded)
func unhideChildren(openedParent: ItemId,
                    parentIndex: Int,
                    parentY: CGFloat,
                    _ masterList: MasterList) -> (MasterList, Int) {
    
    guard let excludedChildren = masterList.excludedGroups[openedParent] else {
        fatalError("Attempted to open a parent that did not have excluded children")
    }
    
    log("unhideChildren: parentIndex: \(parentIndex)")
    
    let parent = retrieveItem(openedParent, masterList.items)
    
    // if you start with the parent, you double add it
    let (updatedMaster, lastIndex, _) = unhideChildrenHelper(
        item: parent,
        currentHighestIndex: parent.itemIndex(masterList.items),
        currentHighestHeight: parent.location.y,
        masterList,
        isRoot: true)
    
    return (updatedMaster, lastIndex)
    
}



// all children, closed or open
func childrenForParent(parentId: ItemId,
                       _ items: RectItems) -> RectItems {
    items.filter { $0.parentId == parentId }
}

//// the currently-open/present children
//// includes nested all the way down
//func _childrenForParent(parentId: ItemId,
//                       _ items: RectItems) -> RectItems {
//
////    items.filter { $0.parentId == parentId }
//
//    for item in items {
//
//    }
//
//
//}




let VIEW_HEIGHT: Int = 100

// is this really correct for nested groups that have been re-opened?

// for should pass in not parentIndex, but index of LAST INSERTED CHILD

func adjustItemsBelow(_ parentId: ItemId,
                      _ parentIndex: Int, // parent that was opened or closed
                      adjustment: CGFloat, // down = +y; up = -y
                      _ items: RectItems) -> RectItems {
    
//    let parentIndex = parentItem.itemIndex(items)
    
    return items.map { item in
        // ie is this item below the parent?
        // below = item's
//        if item.itemIndex(items) > parentIndex {
        
        // only adjust items below the parent
        if item.itemIndex(items) > parentIndex,
            // ... but don't adjust children of the parent,
            // since their position was already set in `unhideGroups`;
            // and when hiding a group, there are no children to adjust.
           item.parentId != parentId {
            var item = item
            // adjust both location and previousLocation
            item.location = CGPoint(x: item.location.x,
                                    y: item.location.y + adjustment)
            item.previousLocation = item.location
            return item
        } else {
            print("Will not adjust item \(item.color)")
            return item
        }
    }
}

// used for
func adjustNonDescendantsBelow(_ lastIndex: Int, // the last item
                               adjustment: CGFloat, // down = +y; up = -y
                               _ items: RectItems) -> RectItems {
    
    return items.map { item in
        if item.itemIndex(items) > lastIndex {
            var item = item
            item.location = CGPoint(x: item.location.x,
                                    y: item.location.y + adjustment)
            item.previousLocation = item.location
            return item
        } else {
            return item
        }
    }
}


func log(_ string: String) {
    print(string)
}

// are you really distinguishing between indices and items?
func retrieveItem(_ id: ItemId, _ items: RectItems) -> RectItem {
    items.first { $0.id == id }!
}

// does this itemId have any children, whether excluded or included?
func hasChildren(_ parentId: ItemId, _ masterList: MasterList) -> Bool {
    
    if masterList.excludedGroups[parentId].isDefined {
        return true
    } else {
        return !childrenForParent(parentId: parentId, masterList.items).isEmpty
    }
}


func isGroupClosed(_ parentId: ItemId, _ master: MasterList) -> Bool {
    // if this item has excluded children, then it is closed
    master.excludedGroups[parentId].isDefined
}


// When group closed:
// - remove parent's children from `items`
// - add removed children to ExcludedGroups dict
// - move up the position of items below the now-closed parent

func groupClosed(closedId: ItemId,
                 _ masterList: MasterList) -> MasterList {
    print("groupClosed called")
    
    let closedParent = retrieveItem(closedId, masterList.items)
    
    if !hasOpenChildren(closedParent, masterList.items) {
        log("groupClosed: \(closedId) had no children; exiting early")
        return masterList
    }
    
    let descendantsCount = getDescendants(
        closedParent,
        masterList.items).count
    
    let moveUpBy = descendantsCount * VIEW_HEIGHT
    
    var masterList = masterList
    
    // hide the children:
    // - populates ExcludedGroups
    // - removes now-hidden descendants from `items`
    masterList = hideChildren(closedParentId: closedId,
                              masterList)
    
    // and move any items below this parent upward
    masterList.items = adjustItemsBelow(
        // parent's own index should not have changed if we only
        // removed or changed items AFTER its index.
        closedParent.id,
        closedParent.itemIndex(masterList.items),
        adjustment: -CGFloat(moveUpBy),
        masterList.items)

    return masterList
}

// When group opened:
// - move parent's children from ExcludedGroups to Items
// - wipe parent's entry in ExcludedGroups
// - move down (+y) any items below the now-open parent
func groupOpened(openedId: ItemId,
                 _ masterList: MasterList) -> MasterList {
    
    log("groupOpened called")

    var masterList = masterList
    
    let parentItem = retrieveItem(openedId, masterList.items)
    let parentIndex = parentItem.itemIndex(masterList.items)
    
    //
    let originalCount = masterList.items.count
    
    let (updatedMaster, lastIndex) = unhideChildren(
        openedParent: openedId,
        parentIndex: parentIndex,
        parentY: parentItem.location.y,
        masterList)
    
    masterList = updatedMaster

    // count after adding hidden descendants back to `items`
    let updatedCount = masterList.items.count
    
    // how many items total we added by unhiding the parent's children
    let addedCount = updatedCount - originalCount
    
    let moveDownBy = addedCount * VIEW_HEIGHT
        
    // and move any items below this parent DOWN
    // ... but skip any children, since their positions' have already been udpated
    masterList.items = adjustNonDescendantsBelow(
        lastIndex,
        adjustment: CGFloat(moveDownBy),
        masterList.items)
    
    log("groupOpened: masterList is now: \(masterList)")
    
    return masterList
}



// works!
func getMovedtoIndex(item: RectItem,
                     items: RectItems,
                     viewHeight: Int = 100) -> Int {
    
    let maxIndex = items.count - 1
    let maxY = maxIndex * viewHeight
//    print("getMovedtoIndex: item.color: \(item.color)")
//    print("getMovedtoIndex: maxY: \(maxY)")
    
    // no, needs to be by steps of 100
    // otherwise 0...800 will be 800 numbers
    
    let range = (0...maxY).reversed().filter { $0.isMultiple(of: viewHeight) }
//    print("getMovedtoIndex: range: \(range)")
    
//    print("getMovedtoIndex: item.location.y: \(item.location.y)")
    
    for threshold in range {
        if item.location.y > CGFloat(threshold) {
//            print("getMovedtoIndex: found at threshold: \(threshold)")
            let i = threshold/viewHeight
//            print("getMovedtoIndex: i: \(i)")
            return i
        }
    }
    
    // if didn't find anything, return the original index?
    let k = items.firstIndex { $0.id == item.id }!
//    print("getMovedtoIndex: k: \(k)")
    return k
}


// used only during on drag;
func updatePositionsHelper(_ item: RectItem,
                           _ items: RectItems,
                           _ indicesToMove: [Int],
                           _ translation: CGSize,
                           // true = `item` is child of the being-dragged item
                           // in which case we don't edit its x-location
//                           isMovedChild: Bool
                           
                           parentIndentation: CGFloat?) -> (RectItems, [Int]) {
    
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
        translation: translation,
        location: item.previousLocation,
        parentIndentation: parentIndentation)
    
    print("updatePositionsHelper: item.location is now: \(item.location)")
    print("updatePositionsHelper: item.previousLocation is now: \(item.previousLocation)")
    
    let index: Int = items.firstIndex { $0.id == item.id }!
    items[index] = item
    indicesToMove.append(index)
    
    items.forEach { childItem in
        if let parentId = childItem.parentId,
           parentId == item.id,
           // don't update the item again, since you already did that
           childItem.id != item.id {
            let (newItems, newIndices) = updatePositionsHelper(
                childItem,
                items,
                indicesToMove,
                translation,
                // parentIndentation for this child will be `item`'s indentation
                parentIndentation: item.location.x)
            
            for newItem in newItems {
                let i = items.firstIndex { $0.id == newItem.id }!
                items[i] = newItem
            }
            indicesToMove = newIndices
        }
    }
    
    return (items, indicesToMove)
}


func adjustMoveToIndex(calculatedIndex: Int,
                       originalItemIndex: Int,
                       movedIndices: [Int],
                       maxIndex: Int) -> Int {
    
    var calculatedIndex = calculatedIndex
    
    // Suppose we have [blue, black, green],
    // blue is black's parent,
    // and blue and green are both top level.
    // If we move blue down, `getMovedtoIndex` will give us a new index of 1 instead of 0.
    // But index 1 is the position of blue's child!
    // So we add the diff.
    
    
//    if calculatedIndex > originalItemIndex {
//        let diff = calculatedIndex - originalItemIndex
//        print("diff: \(diff)")
//        calculatedIndex = calculatedIndex + diff
//        print("calculatedIndex is now: \(calculatedIndex)")
//        if calculatedIndex > maxIndex {
//            print("calculatedIndex was too large, will use max index instead")
//            calculatedIndex = maxIndex
//        }
//        return calculatedIndex
//    }
    
    if calculatedIndex > originalItemIndex {
        let diff = calculatedIndex - originalItemIndex
        print("diff: \(diff)")
            
        // movedIndices is never going to be empty!
        // it always has at least a single item
        if movedIndices.isEmpty {
            calculatedIndex = calculatedIndex + diff
            print("empty movedIndices: calculatedIndex is now: \(calculatedIndex)")
        } else {
            let maxMovedIndex = movedIndices.max()!
            print("maxMovedIndex: \(maxMovedIndex)")
            calculatedIndex = maxMovedIndex + diff
            print("nonEmpty movedIndices: calculatedIndex is now: \(calculatedIndex)")
        }
        
        if calculatedIndex > maxIndex {
            print("calculatedIndex was too large, will use max index instead")
            calculatedIndex = maxIndex
        }
        return calculatedIndex
        
    }
    
    else {
        print("Will NOT adjust moveTo index")
        return calculatedIndex
    }
}


func maybeMoveIndices(_ items: RectItems,
                      indicesMoved: [Int],
                      to: Int,
                      originalIndex: Int) -> RectItems {
    
    var items = items
    
    if to != originalIndex {
        print("maybeMoveIndices: Will move...")
                
        /*
         listData.move(fromOffsets: IndexSet(integer: from),
                       toOffset: to > from ? to + 1 : to)
         */
        
//        print("maybeMoveIndices: items BEFORE move: \(items)")
        print("maybeMoveIndices: items by color BEFORE move: \(items.map(\.color))")
        
        let finalOffset = to > originalIndex ? to + 1 : to
        
        print("maybeMoveIndices: finalOffset: \(finalOffset)")
        
        items.move(fromOffsets: IndexSet(indicesMoved),
                   toOffset: finalOffset)
        
//        print("maybeMoveIndices: items AFTER move: \(items)")
        print("maybeMoveIndices: items by color AFTER move: \(items.map(\.color))")
        
        items = setYPositionByIndices(items,
                                      isDragEnded: false)
        
         print("maybeMoveIndices: items after position reset by indices: \(items)")
        
        return items
    } else {
        print("maybeMoveIndices: Will NOT move...")
        return items
    }
}


func onDragged(_ item: RectItem, // assumes we've already
               _ translation: CGSize,
               _ items: [RectItem]) -> (RectItems, ProposedGroup?) {
    
    print("onDragged called")
    var item = item
    var items = items
    
    print("onDragged: item was: \(item)")
    print("onDragged: items was: \(items)")
        
    let originalItemIndex = items.firstIndex { $0.id == item.id }!
    
    let (newItems, newIndices) = updatePositionsHelper(
        item,
        items,
        [],
        translation,
        // only non-nil when updating position of item's children
        parentIndentation: nil)
    
    items = newItems
    item = items[originalItemIndex] // update the `item` too!
    
    print("onDragged: newItems: \(newItems)")
    print("onDragged: new item: \(item)")
    print("onDragged: newIndices: \(newIndices)")
    
    
    var calculatedIndex = getMovedtoIndex(item: item, items: items)
    
    calculatedIndex = adjustMoveToIndex(
        calculatedIndex: calculatedIndex,
        originalItemIndex: originalItemIndex,
        movedIndices: newIndices,
        maxIndex: items.count - 1)

    
    print("originalItemIndex: \(originalItemIndex)")
    print("calculatedIndex: \(calculatedIndex)")

    items = maybeMoveIndices(items,
                             indicesMoved: newIndices,
                             to: calculatedIndex,
                             originalIndex: originalItemIndex)
    
    //return items
    
    // move items, adjust indices etc.,
    // THEN propose possible groups
    
    // have to retrieve the updated `item` from updated `items` again
    
    let updatedOriginalIndex = item.itemIndex(items)
    item = items[updatedOriginalIndex]
    
    let proposed = proposedGroup(item, items)
    
    return (items, proposed)
}


// grab the first, immediately above parent;
// furthermore, try to grab
// grab the most specific (ie deeply indented) parent as possible;

// if a dragged-item has an item below it with a non-nil parent id,
// then dragged-item sits in the middle of a group and we MUST use that group
func groupFromChildBelow(_ item: RectItem,
                         _ items: RectItems) -> ProposedGroup? {
    
    let movedItemIndex = item.itemIndex(items)
    let indexBelow: Int = movedItemIndex + 1
    
    if let itemBelow = items[safeIndex: indexBelow],
//       itemBelow.parentId.isDefined {
       let parentOfItemBelow = itemBelow.parentId,
       parentOfItemBelow != item.id {
        log("groupFromChildBelow: found child below")
        return ProposedGroup(parentId: itemBelow.parentId!,
                             xIndentation: itemBelow.location.x)
    } else {
        log("groupFromChildBelow: no eligible child below")
        // item
        return nil
    }
}

func getItemsBelow(_ item: RectItem, _ items: RectItems) -> RectItems {
    let movedItemIndex = item.itemIndex(items)
    // eg if movedItem's index is 5,
    // then items below have indices 6, 7, 8, ...
    return items.filter { $0.itemIndex(items) > movedItemIndex }
}

func getItemsAbove(_ item: RectItem, _ items: RectItems) -> RectItems {
    let movedItemIndex = item.itemIndex(items)
    // eg if movedItem's index is 5,
    // then items above have indices 4, 3, 2, ...
    return items.filter { $0.itemIndex(items) < movedItemIndex }
}

// are we moved East enough to align with a child above us?
// if so, use that child's indentation level and parentId
func findDeepestParent(_ item: RectItem, // the moved-item
                       _ items: RectItems) -> ProposedGroup? {
    
    var proposed: ProposedGroup? = nil
    log("findDeepestParent: item.location.x: \(item.location.x)")
    
    for itemAbove in getItemsAbove(item, items) {
        log("findDeepestParent: itemAbove.id: \(itemAbove.id)")
        log("findDeepestParent: itemAbove.location.x: \(itemAbove.location.x)")
        // ie is this dragged item at, or east of, the above item?
        if item.location.x >= itemAbove.location.x {
           // ie only interested in items that are part of a group;
           // otherwise we're just talking about a top level placement
//           itemAbove.parentId.isDefined {
            // ^^ no longer true, since we're cjecking for top level item elsewhere?
            
            // if the item above is itself part of a group,
            // we'll
            if let itemAboveParentId = itemAbove.parentId {
                log("found itemAbove with parent: \(itemAbove.parentId)")
                proposed = ProposedGroup(
                    parentId: itemAboveParentId,
                    xIndentation: itemAbove.location.x)
            }
            // if the item above is NOT itself part of a group,
            // we'll just use the item above now as its paretn
            else {
                log("found itemAbove without parent")
                proposed = ProposedGroup(
                    parentId: itemAbove.id,
//                    xIndentation: itemAbove.location.x)
                    xIndentation: IndentationLevel(1).toXLocation)
                // ^^^ if item has no parent ie is top level,
                // then need this indentation to be at least one level
            }
            log("findDeepestParent: found proposed: \(proposed)")
            log("findDeepestParent: ... for itemAbove: \(itemAbove.id)")
        }
    }
    log("findDeepestParent: final proposed: \(proposed)")
    return proposed
}


// good, BUT: if the top level item is itself a parent, then w
// should be: is blocked by a child-less top-level item immediately above
func blockedByTopLevelItemImmediatelyAbove(_ item: RectItem,
                                           _ items: RectItems) -> Bool {
    
    let index = item.itemIndex(items)
    if let immediatelyAbove = items[safeIndex: index - 1],
       // `parentId: nil` = item is top level
        !immediatelyAbove.parentId.isDefined,
       // `empty children` = item is not a parent to anything
       childrenForParent(parentId: immediatelyAbove.id, items).isEmpty {
        
        log("blocked by child-less top-level item immediately above")
        return true
    }
    return false
}

// retrieves item immediately above, whether that item:
// 1. is a parent (ie has children)
//func getItemImmediatelyAbove



func proposedGroup(_ item: RectItem, // the moved-item
                    _ items: RectItems) -> ProposedGroup? {
    
    // does the item have a non-parent top-level it immediately above it?
    // if so, that blocks group proposal
    if blockedByTopLevelItemImmediatelyAbove(item, items) {
        return nil
    }
    // ie is the item in between two children? If so, it belongs to that group
    else if let proposed = groupFromChildBelow(item, items) {
        return proposed
    } else if let proposed = findDeepestParent(item, items) {
        return proposed
    } else {
        log("no suggested group for item \(item.id), color: \(item.color)")
        return nil
    }
}

func updateItem(_ item: RectItem, _ items: RectItems) -> RectItems {
    let index = item.itemIndex(items)
    var items = items
    items[index] = item
    return items
}

// called in `onDragEnded`

// you're just updating a single item
// but need to update all the descendants as well?
func moveItemIntoGroup(_ item: RectItem,
                       _ items: RectItems,
                       _ proposedGroup: ProposedGroup) -> RectItems {
    var item = item
    var items = items
    
    item.parentId = proposedGroup.parentId
    item.location.x = proposedGroup.xIndentation
    
    // update previousLocation too
    item.previousLocation = item.location
    
    log("moveItemIntoGroup: item.location.x: \(item.location.x)")
//    return updateItem(item, items)
    items = updateItem(item, items)
    let updatedItem = retrieveItem(item.id, items)
    
    return maybeSnapDescendants(updatedItem, items)
    
}


// called in `onDragEnded`

// this needs to also set the x location for all the descendants as well
func moveItemToTopLevel(_ item: RectItem,
                        _ items: RectItems) -> RectItems {

    var item = item
    var items = items
    
    // top level items have no parent,
    // and have x = 0 indentation
    item.parentId = nil
    item.location.x = 0
    
    // update previousLocation too
    item.previousLocation = item.location
    
    log("moveItemToTopLevel: item.location.x: \(item.location.x)")
    log("moveItemToTopLevel: item.parentId: \(item.parentId)")
    
    items = updateItem(item, items)
    let updatedItem = retrieveItem(item.id, items)
    
    return maybeSnapDescendants(updatedItem, items)

}

func maybeSnapDescendants(_ item: RectItem,
                          _ items: RectItems) -> RectItems {
    
    let descendants = getDescendants(item, items)

    if descendants.isEmpty {
        log("maybeSnapDescendants: no children for this now-top-level item \(item.id); exiting early")
        return items
    }

    var items = items
    
    // how to set these indentations appropriately?
    // you don't have guaranteed clean indentation-levels
    // every time you encoutner a parentId, you increment the nesting level

    // starts: parent indentation + 1
    // ^^ does this assume its top level?
//    var indentationLevel = IndentationLevel(0).inc()
    var indentationLevel = item.indentationLevel.inc()
    var currentParentId = item.id
    
    log("maybeSnapDescendants: indentationLevel at start: \(indentationLevel)")
    log("maybeSnapDescendants: currentParentId at start: \(currentParentId)")

    for child in descendants {

        log("maybeSnapDescendants: on child: \(child)")
        // if we've changed parent ids, then we're on a new nesting level
        // ... but maybe not correct when eg
        if let childParentId = child.parentId,
            childParentId != currentParentId {

            currentParentId = childParentId
            
            // this child is east of our previous indentation level,
            // so we went deeper into nesting
            if child.location.x > indentationLevel.toXLocation {
                log("maybeSnapDescendants: child was east")
                indentationLevel = indentationLevel.inc()
            }
            
            // this child is west of our previous indentation level,
            // so we backed out a level
            else if child.location.x < indentationLevel.toXLocation {
                log("maybeSnapDescendants: child was west")
                indentationLevel = indentationLevel.dec()
            }
            
//            indentationLevel = indentationLevel.inc()
            // ^^ not gonna work when eg we've backtracked on a nesting
            // ... must use child's own indentation level +/- 1,
            // depending upon whether this new child is east/west
            // west = indent - 1
            // level = indent + 1
        }

        var child = child
        child = setXLocationByIndentation(child, indentationLevel)
        items = updateItem(child, items)
    }
    
    return items
}


func setXLocationByIndentation(_ item: RectItem,
                               _ indentationLevel: IndentationLevel) -> RectItem {
    var item = item
    item.location.x = indentationLevel.toXLocation
    item.previousLocation = item.location
    return item
}


func onDragEnded(_ item: RectItem,
                 _ items: RectItems,
                 proposed: ProposedGroup?) -> RectItems {
    
    print("onDragEnded called")
    var items = items
    
    // finalizes items' positions by index;
    // also updates itemns' previousPositions.
    items = setYPositionByIndices(items, isDragEnded: true)
    print("onDragEnded: updated items: \(items)")
    
    // now that we've finalized the y-position of the items,
    // we need to potentially:
    // 1: add a parent id to the done-dragging item
    // 2: adjust done-dragging item's x-indentation
    // LATER?: also update an existing groups dict?
    if let proposed = proposed {
        log("onDragEnded: had proposed: \(proposed)")
        let updatedItem = items.first { $0.id == item.id }!
        items = moveItemIntoGroup(updatedItem,
                                  items,
                                  proposed)
    }
    
    // if no proposed group, then we moved item to top level:
    // 1. reset done-dragging item's x to `0`
    // 2. set item's parent to nil
    else {
        log("onDragEnded: no proposed group; will snap to top level")
        let updatedItem = items.first { $0.id == item.id }!
        items = moveItemToTopLevel(updatedItem, items)
    }

    print("onDragEnded: final items: \(items)")
    return items
}

// accepts `parentIndentation`
// eg a child of a top level item will receive `parentIndentation = 50`
// and so child's x location must always be 50 greater than its parent
func updatePosition(translation: CGSize,
                    // usually: previousPosition
                    location: CGPoint,
                    //
                    parentIndentation: CGFloat?) -> CGPoint {
    
    var adjustedX = translation.width + location.x
    
    // a child being moved because we're dragging some higher up parent,
    // should not have its indentation changed
//    if isMovedChild {
//        log("updatePosition: tried to drag West; will correct to x = 0")
//        adjustedX = location.x
//    }
    
    // we can ever go West; can only drag East
    if adjustedX < 0 {
        log("updatePosition: tried to drag West; will correct to x = 0")
        adjustedX = 0
    }
    

    // We must always be 50 points east of our parent
    if let parentIndentation = parentIndentation {
        log("updatePosition: had parent indentation of \(parentIndentation)")
        adjustedX = parentIndentation + CGFloat(INDENTATION_LEVEL)
    }
    // ^^ when moving a nested group,
    // it kept thinking that we had some parent identation (which was true!)
    // so we were always getting some positive adjustedX;
    // whereas really,
    
    // ... should parentIndentation be ignored
    // each a nested item's
    // eg when being-dragged-item is nested, it will have a parent which will have an indentation
    // ... but that's not actually the indentation we want to use in that case.
    // Instead, we just want
    
    
//    // we can ever go West; can only drag East
//    if adjustedX < 0 {
//        log("updatePosition: tried to drag West; will correct to x = 0")
//        adjustedX = 0
//    }
    
//    CGPoint(x: translation.width + location.x,
    return CGPoint(x: adjustedX,
                   y: translation.height + location.y)
}

// eg given some existing items, with various positions,

// ie the order of the items now reflects what we want;
// and so we reset the items' positions to follow that order

// assumes we're dealing with a master list

// ie we've just REORDERED `items`,
// and now want to set their heights according to the REORDERED items;
// hence why we use `.enumerated`'s offsets, and not
func setYPositionByIndices(_ items: RectItems,
                           isDragEnded: Bool = false,
                           _ viewHeight: Int = 100) -> RectItems {

    
    items.enumerated().map { (offset, item) in
        // need to keep the level of nesting, which never changes when reseting positions
//        let newLocation = CGPoint(x: 0,
        var item = item
        let newY = CGFloat(offset * viewHeight)
//        print("setYPositionByIndices: item: \(item)")
//        print("setYPositionByIndices: newY: \(newY)")
        
        // Setting position by indices NEVER changes x location
        let newLocation = CGPoint(x: item.location.x,
                                  y: newY)
        item.location = newLocation
        if isDragEnded {
            print("setYPositionByIndices: drag ended, so resetting previous position")
            item.previousLocation = newLocation
        }
        return item
    }
}

struct ContentView: View {
    
    @State private var masterList = generateData()
    
    // the current id being dragged
    // nil when we're not dragging anything
    @State var current: ItemId? = nil
    
    // nil = top level proposed
    // non-nil = deepested nested group possible to join,
    // based on dragged-item's current x position
    @State var proposedGroup: ProposedGroup? = nil
    
    var body: some View {
        ZStack {
            Text("RESET").onTapGesture {
                masterList = generateData()
                current = nil
                proposedGroup = nil
            }.scaleEffect(2).offset(x: 500)
            
            ForEach(masterList.items, id: \.id.value) { (d: RectItem) in
                RectView2(item: d,
                          masterList: $masterList,
                          current: $current,
                          proposedGroup: $proposedGroup)
                    .zIndex(Double(d.zIndex))
            } // ForEach
        } // ZStack
        .animation(.default)
        .offset(x: -200, y: -300)
    }
}


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
    MyColor(color: .red),
    MyColor(color: .blue, children: [
        MyColor(color: .black),
        MyColor(color: .brown)
    ]),
    MyColor(color: .green),
    MyColor(color: .yellow)
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

let sampleColors4: [MyColor] = [
    MyColor(color: .red),
    MyColor(color: .blue, children: [
        MyColor(color: .black),
        MyColor(color: .brown, children: [
            MyColor(color: .cyan),
            MyColor(color: .purple)

        ]),
        MyColor(color: .indigo, children: [
            MyColor(color: .orange),
            MyColor(color: .gray),
        ]),
    ]),
    MyColor(color: .green),
    MyColor(color: .yellow)
]

func generateData() -> MasterList {
    MasterList.fromColors(
        //        sampleColors0
//                sampleColors1
                sampleColors2
//                sampleColors3
    )
}

