import SwiftUI


// // MARK: CONSTANTS

// was:
//let RECT_HEIGHT: CGFloat = 100

// now
let RECT_HEIGHT: CGFloat = CGFloat(VIEW_HEIGHT)


let RECT_WIDTH: CGFloat = 400
//let RECT_WIDTH: CGFloat = 200

let VIEW_HEIGHT: Int = 200

let INDENTATION_LEVEL: Int = VIEW_HEIGHT / 2





// // MARK: EXTENSIONS

func log(_ string: String) {
    print(string)
}

func logInView(_ log: String) -> EmptyView {
    print("** \(log)")
    return EmptyView()
}

extension Array {
    public subscript(safeIndex index: Int) -> Element? {
        guard index >= 0, index < endIndex else {
            return nil
        }
        return self[index]
    }
}

extension Optional {
    var isDefined: Bool {
        self != nil
    }
}

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


// only called if parent has children
func hideChildren(closedParentId: ItemId,
                  _ masterList: MasterList) -> MasterList {
    
    var masterList = masterList
    
    let closedParent = retrieveItem(closedParentId, masterList.items)
    
    
    // if there are no descendants, then we're basically done
    
    // all the items below this parent, with indentation > parent's
    let descendants = getDescendants(closedParent, masterList.items)
    
    // starting: immediate parent will have closed parent's id
    var currentParent: ItemId = closedParentId
    
    // starting: immediate child of parent will have parent's indentation level + 1
    var currentDeepestIndentation = closedParent.indentationLevel.inc()
    
    for descendant in descendants {
//        log("on descendant: \(descendant)")
        
        // if we ever have a descendant at, or west of, the closedParent,
        // then we made a mistake!
        if descendant.indentationLevel.value <= closedParent.indentationLevel.value {
            fatalError()
        }
        
        // if this descendant is in the same nesting level,
        // just added it to
        if descendant.indentationLevel == currentDeepestIndentation {
            
            // must be false if currentParent i
            // can only possibly be true for subgroups,
            // so must be false if currentParent is still the closedParent;
            
            // only true if currentParent != closedParent.id,
            // and excludedGroups ALREADY INCLUDES this subgroup parent (ie descendant)
            
            
            masterList = masterList.appendToExcludedGroup(
                for: currentParent,
                   descendant)
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
                for: currentParent,
                   descendant)
        }
    }
    
    // finally, remove descendants from items list
    let descendentsIdSet: Set<ItemId> = Set(descendants.map(\.id))
    
    masterList.items.removeAll { descendentsIdSet.contains($0.id) }
    
//    log("hideChildren: masterList is now: \(masterList)")
    
    return masterList
}


// retrieve children
// nil = parentId had no
// non-nil = returning children, plus removing the parentId entry from ExcludedGroups
func popExcludedChildren(parentId: ItemId,
                         _ masterList: MasterList) -> (RectItems, ExcludedGroups)? {
    
    if let excludedChildren = masterList.excludedGroups[parentId] {
        
        // prevents us from opening any subgroups that weren't already opend
        if masterList.collapsedGroups.contains(parentId) {
            log("this subgroup was closed when it was put away, so will skip it")
            return nil
        }
        
        var groups = masterList.excludedGroups
        groups.removeValue(forKey: parentId)
        return (excludedChildren, groups)
    }
    return nil
}

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
    
    // does this `item` have children of its own?
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

// are you really distinguishing between indices and items?
func retrieveItem(_ id: ItemId, _ items: RectItems) -> RectItem {
    items.first { $0.id == id }!
}

func hasChildren(_ parentId: ItemId, _ masterList: MasterList) -> Bool {

    if let x = masterList.items.first(where: { $0.id == parentId }),
       x.isGroup {
//        log("hasChildren: true because isGroup")
        return true
    } else if masterList.excludedGroups[parentId].isDefined {
//        log("hasChildren: true because has entry in excludedGroups")
        return true
    } else if !childrenForParent(parentId: parentId, masterList.items).isEmpty {
//        log("hasChildren: true because has non-empty children in on-screen items")
        return true
    } else {
//        log("hasChildren: false....")
        return false
    }
}


func getMovedtoIndex(item: RectItem,
                     items: RectItems,
                     draggedAlong: ItemIdSet) -> Int {
        
    var maxIndex = items.count - 1
    
    // special case:
    // if we moved a parent to the end of the items (minus parents' own children),
    // then don't adjust-by-indices while dragging.
    if item.isGroup {
        
        let itemsWithoutDraggedAlong = items.filter { x in !draggedAlong.contains(x.id) }
        
            print("getMovedtoIndex: special case maxIndex: \(maxIndex)")
            maxIndex = itemsWithoutDraggedAlong.count - 1
    }
    
    let maxY = maxIndex * VIEW_HEIGHT
    
//    print("getMovedtoIndex: item.color: \(item.color)")
    print("getMovedtoIndex: item: \(item)")
    print("getMovedtoIndex: maxY: \(maxY)")
    
    // no, needs to be by steps of 100
    // otherwise 0...800 will be 800 numbers
    
    let range = (0...maxY).reversed().filter { $0.isMultiple(of: VIEW_HEIGHT) }
    
        print("getMovedtoIndex: range: \(range)")
        print("getMovedtoIndex: item.location.y: \(item.location.y)")
    
    for threshold in range {
        if item.location.y > CGFloat(threshold) {
            print("getMovedtoIndex: found at threshold: \(threshold)")
            let i = threshold/VIEW_HEIGHT
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
                           _ translation: CGSize,
                           beingDragged: ItemId,
//                           beingDraggedNeedsUpdate: Bool,
                           isRoot: Bool,
                           draggedAlong: ItemIdSet,
                           parentIndentation: CGFloat?) -> (RectItems, [Int], ItemIdSet) {
    
    print("updatePositionsHelper called")
    var item = item
    var items = items
    var indicesToMove = indicesToMove
    var draggedAlong = draggedAlong
    
    //    let originalItemIndex = items.firstIndex { $0.id == item.id }!
    
    print("updatePositionsHelper: item.location was: \(item.location)")
    print("updatePositionsHelper: item.previousLocation was: \(item.previousLocation)")
    
    // more, if this `item` has children
    //    var indicesofItemsToMove: [Int] = [originalItemIndex]
    
    // always update the item's position first:
    
    // WHILE DRAGGING, THE DRAG GESTURE DOES NOT UPDATE THE ACTUAL POSITIONS OF THE ITEMS;
    // ONLY THE GROUP-BASED SNAP CAN DO THAT.
    // INSTEAD, WE ACCUMULATE THE X-TRANSLATIONS IN CURSOR DRAG,
    // WHICH DETERMINES WHICH GROUP GETS PROPOSED.
    
//    item.id != beingDragged
    
//    if !isRoot {
//        item.location = updatePosition(
//            translation: translation,
//            location: item.previousLocation,
//            parentIndentation: parentIndentation)
//
//        print("updatePositionsHelper: item.location is now: \(item.location)")
//        print("updatePositionsHelper: item.previousLocation is now: \(item.previousLocation)")
//
//        let index: Int = items.firstIndex { $0.id == item.id }!
//        items[index] = item
//        indicesToMove.append(index)
//    } else {
//        log("updatePositionsHelper: had root item \(item.id); will not update it again")
//    }
            
    item.location = updatePosition(
        translation: translation,
        location: item.previousLocation)

    print("updatePositionsHelper: item.location is now: \(item.location)")
    print("updatePositionsHelper: item.previousLocation is now: \(item.previousLocation)")

    let index: Int = items.firstIndex { $0.id == item.id }!
    items[index] = item
    indicesToMove.append(index)
    
    print("updatePositionsHelper: indicesToMove: \(indicesToMove)")
    
    "updatePositionsHelper: item.id != beingDragged: \(item.id != beingDragged)"
    
    // this is ALL the items
    
    // is this really correct?
    // if you're checking for children for `item`,
    items.forEach { childItem in
        if let parentId = childItem.parentId,
           parentId == item.id,
           // don't update the item again, since you already did that
           childItem.id != item.id //,
           
            // added:
//           childItem.id != beingDragged // ,
           
            // item.id == beingDragged is ALWAYS TRUE WHEN CALLED FROM ROOT
//            item.id != beingDragged,
           
        {
            
            // we never update the parent again
            log("updatePositionsHelper: will update childItem by id: \(childItem.id)")
            log("updatePositionsHelper: will update childItem by: location: \(childItem.location), previousLocation: \(childItem.previousLocation)")
            
            draggedAlong.insert(childItem.id)
            
            let (newItems, newIndices, updatedDraggedAlong) = updatePositionsHelper(
                childItem,
                items,
                indicesToMove,
                translation,
                beingDragged: beingDragged,
                isRoot: false,
                draggedAlong: draggedAlong,
                // parentIndentation for this child will be `item`'s indentation
                parentIndentation: item.location.x)
            
            for newItem in newItems {
                let i = items.firstIndex { $0.id == newItem.id }!
                items[i] = newItem
            }
            
            // you're OVERRIDING THIS?
            indicesToMove = newIndices
            
            draggedAlong = draggedAlong.union(updatedDraggedAlong)
        }
    }

    return (items, indicesToMove, draggedAlong)
}


// doesn't seem to work for a moved parent;
// we end up
func adjustMoveToIndex(calculatedIndex: Int,
                       originalItemIndex: Int,
                       movedIndices: [Int],
                       maxIndex: Int) -> Int {
    
    log("adjustMoveToIndex: movedIndices: \(movedIndices)")
    
    var calculatedIndex = calculatedIndex
    
    // Suppose we have [blue, black, green],
    // blue is black's parent,
    // and blue and green are both top level.
    // If we move blue down, `getMovedtoIndex` will give us a new index of 1 instead of 0.
    // But index 1 is the position of blue's child!
    // So we add the diff.
    
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
                      originalIndex: Int,
                      //added
                      maxIndex: Int) -> RectItems {
    
    log("maybeMoveIndices: indicesMoved: \(indicesMoved)")
    log("maybeMoveIndices: to: \(to)") // ie calculatedIndex
    log("maybeMoveIndices: originalIndex: \(originalIndex)")
    
    var items = items
    
    
    
    if to != originalIndex {
        
            // added
//        if to == maxIndex {
//            log("maybeMoveIndices: to == maxIndex, so will not adjust...")
//            return items
//        }
        // ^^ no, bad.
        
        
        log("maybeMoveIndices: Will move...")
        
        /*
         listData.move(fromOffsets: IndexSet(integer: from),
         toOffset: to > from ? to + 1 : to)
         */
        
//        log("maybeMoveIndices: items by id BEFORE move: \(items.map(\.id))")
//        log("maybeMoveIndices: items by color BEFORE move: \(items.map(\.color))")
        
        let finalOffset = to > originalIndex ? to + 1 : to
        
        log("maybeMoveIndices: finalOffset: \(finalOffset)")
        
        items.move(fromOffsets: IndexSet(indicesMoved),
                   toOffset: finalOffset)
        
//        log("maybeMoveIndices: items by id AFTER move: \(items.map(\.id))")
        
//        log("maybeMoveIndices: items by color AFTER move: \(items.map(\.color))")
        
        items = setYPositionByIndices(items,
                                      isDragEnded: false)
        
//        log("maybeMoveIndices: item ids after position reset by indices: \(items.map(\.id))")
        
        return items
    } else {
        log("maybeMoveIndices: Will NOT move...")
        return items
    }
}

// Grab the item immediately below;
// if it has a parent (which should be above us),
// use that parent as the proposed group.
func groupFromChildBelow(_ item: RectItem,
                         _ items: RectItems,
                         movedItemChildrenCount: Int,
                         excludedGroups: ExcludedGroups) -> ProposedGroup? {
    
    log("groupFromChildBelow: item: \(item)")
    
    let movedItemIndex = item.itemIndex(items)
    let entireIndex = movedItemIndex + movedItemChildrenCount
    
    // must look at the index of the first item BELOW THE ENTIRE BEING-MOVED-ITEM-LIST
    let indexBelow: Int = entireIndex + 1
    
    log("groupFromChildBelow: movedItemIndex: \(movedItemIndex)")
    log("groupFromChildBelow: entireIndex: \(entireIndex)")
    log("groupFromChildBelow: indexBelow: \(indexBelow)")
    // ^^ when you're dragging along eg
    
    guard let itemBelow = items[safeIndex: indexBelow] else {
        log("groupFromChildBelow: no itemBelow")
        return nil
    }
    
    guard let parentOfItemBelow = itemBelow.parentId else {
        log("groupFromChildBelow: no parent on itemBelow")
        return nil
    }
    
    log("groupFromChildBelow: itemBelow: \(itemBelow)")
    log("groupFromChildBelow: itemBelow.parentId: \(itemBelow.parentId)")
    log("groupFromChildBelow: itemBelow.indentationLevel.value: \(itemBelow.indentationLevel.value)")
    log("groupFromChildBelow: item.indentationLevel.value: \(item.indentationLevel.value)")
    
    let itemsAbove = getItemsAbove(item, items)
    
    guard let parentItemAbove = itemsAbove.first(where: { $0.id == parentOfItemBelow }) else {
        log("groupFromChildBelow: could not find parent above")
        return nil
    }
    
    let proposedParent = parentItemAbove.id
    let proposedIndentation = parentItemAbove.indentationLevel.inc().toXLocation
    
    log("groupFromChildBelow: proposedParent: \(proposedParent)")
    log("groupFromChildBelow: proposedIndentation: \(proposedIndentation)")
    
    // we'll use the indentation level of the parent + 1
    return ProposedGroup(parentId: proposedParent,
                         xIndentation: proposedIndentation)
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
//                       _ items: RectItems) -> ProposedGroup? {
                       _ masterList: MasterList,
                       cursorDrag: CursorDrag) -> ProposedGroup? {
    
    var proposed: ProposedGroup? = nil
    
    log("findDeepestParent: item.id: \(item.id)")
    log("findDeepestParent: item.location.x: \(item.location.x)")
    log("findDeepestParent: cursorDrag: \(cursorDrag)")
    
    let items = masterList.items
    let excludedGroups = masterList.excludedGroups
    
//    let itemLocationX = item.location.x
    let itemLocationX = cursorDrag.x
    
    for itemAbove in getItemsAbove(item, items) {
        log("findDeepestParent: itemAbove.id: \(itemAbove.id)")
        log("findDeepestParent: itemAbove.location.x: \(itemAbove.location.x)")
        // ie is this dragged item at, or east of, the above item?
//        if item.location.x >= itemAbove.location.x {
        
//        if item.location.x > itemAbove.location.x {
        if itemLocationX > itemAbove.location.x {
            // ^^ has to be >, not >=, because = is top level in some cases?
            
        
            // ie only interested in items that are part of a group;
            // otherwise we're just talking about a top level placement
            //           itemAbove.parentId.isDefined {
            // ^^ no longer true, since we're cjecking for top level item elsewhere?
            
            // if the item above is itself part of a group,
            // we'll
            
            let itemAboveHasChildren = hasChildren(itemAbove.id, masterList)
            let itemAboveHasParent = itemAbove.parentId.isDefined
            
            // if the itemAbove us itself a parent,
            // then we want to put our being-dragged-item into that itemAbove's child list;
            // and NOT use that itemAbove's own parent as our group
            if itemAboveHasChildren,
               !excludedGroups[itemAbove.id].isDefined {
                log("found itemAbove that has children; will make being-dragged-item")
                
                // make sure it's not a closed group that we're proposing!
                
                
                proposed = ProposedGroup(parentId: itemAbove.id,
                                         xIndentation: itemAbove.indentationLevel.inc().toXLocation)
            }
            
            // this can't quite be right --
            // eg we can find an item above us that has its own parent,
            // we'd wrongly put the being-dragged-item into
            
            else if let itemAboveParentId = itemAbove.parentId,
                    !excludedGroups[itemAboveParentId].isDefined {
                log("found itemAbove that is part of a group whose parent id is: \(itemAbove.parentId)")
                proposed = ProposedGroup(
                    parentId: itemAboveParentId,
                    xIndentation: itemAbove.location.x)
            }
            

            // if the item above is NOT itself part of a group,
            // we'll just use the item above now as its parent
//            else {
            else if !excludedGroups[itemAbove.id].isDefined {
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
        } else {
            log("findDeepestParent: item \(item.id) was not at/east of itemAbove \(itemAbove.id)")
            
        }
    }
    log("findDeepestParent: final proposed: \(proposed)")
    return proposed
}


// good, BUT: if the top level item is itself a parent, then w
// should be: is blocked by a child-less top-level item immediately above
// ... possibly don't even need this function anymore ...

// If blocked by a top level item immediately above,
// then
func blockedByTopLevelItemImmediatelyAbove(_ item: RectItem,
                                           _ items: RectItems) -> Bool {
    
    // is this really accurate?
    let index = item.itemIndex(items)
    if let immediatelyAbove = items[safeIndex: index - 1],
       // `parentId: nil` = item is top level
       !immediatelyAbove.parentId.isDefined
        ,
//    {
        // , {
       
        // ALLOW A TOP LEVEL ITEM TO BE PROPOSED?
        
//        // if the item above us were a group,
//        // then we'd propose that
        !immediatelyAbove.isGroup {
        
        
        // `empty children` = item is not a parent to anything
//       childrenForParent(parentId: immediatelyAbove.id, items).isEmpty {
        log("blocked by child-less top-level item immediately above: immediatelyAbove: \(immediatelyAbove)")
        return true
    }
    return false
}

func proposeGroup(_ item: RectItem, // the moved-item
//                  _ items: RectItems) -> ProposedGroup? {
                  _ masterList: MasterList,
                  _ draggedAlongCount: Int,
                  cursorDrag: CursorDrag) -> ProposedGroup? {
    
    let items = masterList.items
    
    log("proposeGroup: will try to propose group for item: \(item.id)")
    
    // General rule:
    
    var proposed = findDeepestParent(item,
                                     masterList,
                                     cursorDrag: cursorDrag)
    
    log("proposeGroup: proposed from trying to find deepest parent: \(proposed)")
    
    // Exceptions:
    
    // does the item have a non-parent top-level it immediately above it?
    // if so, that blocks group proposal
    if blockedByTopLevelItemImmediatelyAbove(item, items) {
        log("blocked by non-parent top-level item above")
//        return nil
        proposed = nil
    }
    // ie is the item in between two children? If so, it belongs to that group
    
    
    // if the dragged-item has an item below it, or above it,
    //
//    let movedItemChildrenCount = childrenForParent(parentId: item.id, items).count
    let movedItemChildrenCount = draggedAlongCount
    
    // this should also include eg the case where we're moving an item up from n=2 to n=1 nesting level;
    // ie still in same group, but
    
    // maybe only check this when we're sure we're in the middle of a group?
    if let groupDueToChildBelow = groupFromChildBelow(item,
                                                      items,
                                                      movedItemChildrenCount: movedItemChildrenCount,
                                                      excludedGroups: masterList.excludedGroups) {
        
        log("found group \(groupDueToChildBelow.parentId) from child below")
        proposed = groupDueToChildBelow
    }
    
    log("proposeGroup: returning: \(proposed)")
    return proposed
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
                       draggedAlong: ItemIdSet,
                       _ proposedGroup: ProposedGroup) -> RectItems {
    var item = item
    var items = items
    
//    let originalItem = item
    
    item.parentId = proposedGroup.parentId
    item.location.x = proposedGroup.xIndentation
    
    // update previousLocation too
//    item.previousLocation = item.location
    // ^ ?: DON'T DO THIS, now that you're running this is onDrag instead of onDragEnded
    log("moveItemIntoGroup: proposedGroup: \(proposedGroup)")
    
    log("moveItemIntoGroup: item.location.x: \(item.location.x)")
    items = updateItem(item, items)
    let updatedItem = retrieveItem(item.id, items)
    
    return maybeSnapDescendants(updatedItem,
                                items,
                                draggedAlong: draggedAlong,
                                startingIndentationLevel: proposedGroup.indentationLevel)
    
}


// called in `onDragEnded`

// this needs to also set the x location for all the descendants as well
func moveItemToTopLevel(_ item: RectItem,
//                        _ items: RectItems) -> RectItems {
                        _ items: RectItems,
                        draggedAlong: ItemIdSet) -> RectItems {
    
    var item = item
    var items = items
    
    // top level items have no parent,
    // and have x = 0 indentation
    item.parentId = nil
    item.location.x = 0
    
    // update previousLocation too
//    item.previousLocation = item.location
    // ^^ don't do this now that you're calling this fn in onDrag
    
    log("moveItemToTopLevel: item.location.x: \(item.location.x)")
    log("moveItemToTopLevel: item.parentId: \(item.parentId)")
    
    items = updateItem(item, items)
    let updatedItem = retrieveItem(item.id, items)
    
    return maybeSnapDescendants(updatedItem,
                                items,
                                draggedAlong: draggedAlong,
                                startingIndentationLevel: IndentationLevel(0))
    
}


func maybeSnapDescendants(_ item: RectItem,
                          _ items: RectItems,
                          draggedAlong: ItemIdSet,
                          startingIndentationLevel: IndentationLevel) -> RectItems {
    
//    log("maybeSnapDescendants: item at start: \(item)")
    
//    let descendants = getDescendants(item, items)
    let descendants = items.filter { draggedAlong.contains($0.id) }
//    log("maybeSnapDescendants: draggedAlong by id: \(draggedAlong.map(\.id))")
//    log("maybeSnapDescendants: descendants by id: \(descendants.map(\.id))")
    
    if descendants.isEmpty {
//        log("maybeSnapDescendants: no children for this now-top-level item \(item.id); exiting early")
        return items
    }
    
    var items = items
    
    // how to set these indentations appropriately?
    // you don't have guaranteed clean indentation-levels
    // every time you encoutner a parentId, you increment the nesting level
    
    // starts: parent indentation + 1
    // ^^ does this assume its top level?
    //    var indentationLevel = IndentationLevel(0).inc()
    
    // indentation level is relying on previous position,
    // which is never updated during onDrag;
    // instead, use the startingIndentationLevel from the proposedGroup
//    var indentationLevel = item.indentationLevel.inc()
    var indentationLevel = startingIndentationLevel.inc()
    var currentParentId = item.id
    
//    log("maybeSnapDescendants: indentationLevel at start: \(indentationLevel)")
//    log("maybeSnapDescendants: currentParentId at start: \(currentParentId)")
    
    for child in descendants {
        
//        log("maybeSnapDescendants: on child: \(child.id), \(child.color), \(child.location.x), parentId: \(child.parentId)")
        
//        log("maybeSnapDescendants: CURRENT: indentationLevel: \(indentationLevel)")
//        log("maybeSnapDescendants: CURRENT: indentationLevel.toXLocation: \(indentationLevel.toXLocation)")
//        log("maybeSnapDescendants: CURRENT: currentParentId: \(currentParentId)")
        
//        log("maybeSnapDescendants: on child: \(child)")
        // if we've changed parent ids, then we're on a new nesting level
        // ... but maybe not correct when eg
        if let childParentId = child.parentId,
           childParentId != currentParentId {
            
            currentParentId = childParentId
            
            // this child is east of our previous indentation level,
            // so we went deeper into nesting
//            if child.location.x > indentationLevel.toXLocation {
            
            // compare against child's indentation level,
            // which is not changed until the very end of onDragEnded
            if child.indentationLevel.value > indentationLevel.value {
//                log("maybeSnapDescendants: child was east")
                indentationLevel = indentationLevel.inc()
            }
            
            // this child is west of our previous indentation level,
            // so we backed out a level
//            else if child.location.x < indentationLevel.toXLocation {
            else if child.indentationLevel.value < indentationLevel.value {
//                log("maybeSnapDescendants: child was west")
                indentationLevel = indentationLevel.dec()
            } else {
//                log("maybeSnapDescendants: child was aligned")
            }
        }
        
        var child = child
//        log("maybeSnapDescendants: child location BEFORE setXLocationByIndentation: \(child.location.x)")
        child = setXLocationByIndentation(child, indentationLevel)
//        log("maybeSnapDescendants: child location after setXLocationByIndentation: \(child.location.x)")
        items = updateItem(child, items)
    }
    
    return items
}


func setXLocationByIndentation(_ item: RectItem,
                               _ indentationLevel: IndentationLevel) -> RectItem {
    
    var item = item
    item.location.x = indentationLevel.toXLocation
    
    // previousLocation should only be updated in onDragEnded
    
//    item.previousLocation = item.location
//    item.previousLocation.x = item.location.x
    return item
}

// accepts `parentIndentation`
// eg a child of a top level item will receive `parentIndentation = 50`
// and so child's x location must always be 50 greater than its parent


struct CursorDrag: Codable, Equatable {
    var x: CGFloat
    var previousX: CGFloat
    
    // called at start of a drag gesture
    static func fromItem(_ item: RectItem) -> CursorDrag {
        CursorDrag(x: item.location.x,
                   previousX: item.previousLocation.x)
    }
}

// previously, we let this
func updatePosition(translation: CGSize,
                    // usually: previousPosition
                    location: CGPoint) -> CGPoint {
    
    CGPoint(x: location.x, // NEVER adjust
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
    
//    log("will adjust positions of items (by id): \(items.map(\.id))")
    
    return items.enumerated().map { (offset, item) in
        // need to keep the level of nesting, which never changes when reseting positions
        //        let newLocation = CGPoint(x: 0,
        var item = item
        let newY = CGFloat(offset * viewHeight)
        
//        print("setYPositionByIndices: item id: \(item.id)")
//        print("setYPositionByIndices: newY: \(newY)")
        
        // Setting position by indices NEVER changes x location
        let newLocation = CGPoint(x: item.location.x,
                                  y: newY)
        item.location = newLocation
        
        // ONLY SET `previousLocation.y` HERE
        if isDragEnded {
//            print("setYPositionByIndices: drag ended, so resetting previous position")
//            item.previousLocation = newLocation
            item.previousLocation.y = newLocation.y
        }
        return item
    }
}

// // MARK: EVENTS

// When group opened:
// - move parent's children from ExcludedGroups to Items
// - wipe parent's entry in ExcludedGroups
// - move down (+y) any items below the now-open parent
func onGroupOpened(openedId: ItemId,
                 _ masterList: MasterList) -> MasterList {
    
    log("onGroupOpened called")
    
    var masterList = masterList
    
    // important: remove this item from collapsedGroups,
    // so that we can unfurl its own children
    masterList.collapsedGroups.remove(openedId)
    
    let parentItem = retrieveItem(openedId, masterList.items)
    let parentIndex = parentItem.itemIndex(masterList.items)
    
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
    
    log("onGroupOpened: masterList is now: \(masterList)")
    
    return masterList
}

// When group closed:
// - remove parent's children from `items`
// - add removed children to ExcludedGroups dict
// - move up the position of items below the now-closed parent
func onGroupClosed(closedId: ItemId,
                 _ masterList: MasterList) -> MasterList {
    print("onGroupClosed called")
    
    let closedParent = retrieveItem(closedId, masterList.items)

    var masterList = masterList
    
    // when we close an empty group,
    // it won't have an eny children,
    // but we still want it to appear in
    
    
    if !hasOpenChildren(closedParent, masterList.items) {
//        log("onGroupClosed: \(closedId) had no children; exiting early")
        log("onGroupClosed: \(closedId) had no children; adding empty entry")
        
        // since there are no children,
        // we don't need to update excluded groups?
        // ... or should we still have some entry there?
        masterList.collapsedGroups.insert(closedId)
        masterList.excludedGroups.updateValue([], forKey: closedId)
        log("onGroupClosed: masterList.collapsedGroups is now: \(masterList.collapsedGroups)")
        log("onGroupClosed: masterList.excludedGroups is now: \(masterList.excludedGroups)")
        
        return masterList
    }
    
    let descendantsCount = getDescendants(
        closedParent,
        masterList.items).count
    
    let moveUpBy = descendantsCount * VIEW_HEIGHT
    
//    var masterList = masterList
    
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
    
    // add parent to collapsed group
    masterList.collapsedGroups.insert(closedId)
    
    log("onGroupClosed: masterList.items by color: \(masterList.items.map(\.color))")
    
    return masterList
}

//func updateBeingDraggedItemPosition() -> RectItem {
//
//}

func onDragged(_ item: RectItem, // item being actively dragged
               _ translation: CGSize,
               _ masterList: MasterList) -> (MasterList,
                                             ProposedGroup?,
                                             BeingDraggedItem,
                                             CursorDrag) {
    
    log("onDragged called")
    var item = item
    var masterList = masterList
    
    log("onDragged: item was: \(item)")
    log("onDragged: masterList was: \(masterList)")
    
    let originalItemIndex = masterList.items.firstIndex { $0.id == item.id }!
    
    // items dragged along as part of the being-dragged item;
    // does NOT include the `being-dragged-item` itself.
    var draggedAlong = ItemIdSet()
        
    let (newItems, newIndices, updatedDraggedAlong) = updatePositionsHelper(
        item,
        masterList.items,
        [],
        translation,
        beingDragged: item.id,
        isRoot: true,
        draggedAlong: draggedAlong,
        // only non-nil when updating position of item's children
        parentIndentation: nil)
        
    var cursorDrag = CursorDrag.fromItem(item)
    log("onDragged: cursorDrag was: \(cursorDrag)")
    cursorDrag.x = cursorDrag.previousX + translation.width
    log("onDragged: cursorDrag is now: \(cursorDrag)")
    
    masterList.items = newItems
    item = masterList.items[originalItemIndex] // update the `item` too!
    
    draggedAlong = draggedAlong.union(updatedDraggedAlong)
    
    print("onDragged: newItems: \(newItems)")
    print("onDragged: new item: \(item)")
    print("onDragged: newIndices: \(newIndices)")
    
//    let basicMaxIndex = masterList.items.count - 1
//    print("onDragged: basicMaxIndex was: \(basicMaxIndex)")
        
//    let maxIndex = masterList.items.count - 1
    
    var calculatedIndex = getMovedtoIndex(
        item: item,
        items: masterList.items,
        draggedAlong: draggedAlong)
    
//    var calculatedIndex = getMovedtoIndex(
//        item: item,
//        items: masterList.items,
//        maxIndex: maxIndex)
    
    let maxIndex = masterList.items.count - 1
    
    print("onDragged: originalItemIndex: \(originalItemIndex)")
    print("onDragged: calculatedIndex was: \(calculatedIndex)")
    
    calculatedIndex = adjustMoveToIndex(
        calculatedIndex: calculatedIndex,
        originalItemIndex: originalItemIndex,
        movedIndices: newIndices,
        maxIndex: maxIndex)
    
    print("onDragged: calculatedIndex is now: \(calculatedIndex)")

    masterList.items = maybeMoveIndices(
        masterList.items,
        indicesMoved: newIndices,
        to: calculatedIndex,
        originalIndex: originalItemIndex,
        maxIndex: maxIndex)
    
    //return items
    
    // move items, adjust indices etc.,
    // THEN propose possible groups
    
    // have to retrieve the updated `item` from updated `items` again
    
    let updatedOriginalIndex = item.itemIndex(masterList.items)
    item = masterList.items[updatedOriginalIndex]
    
    let proposed = proposeGroup(item, masterList, draggedAlong.count, cursorDrag: cursorDrag)
    
    let beingDragged = BeingDraggedItem(current: item.id,
                                        draggedAlong: draggedAlong)
    
    log("onDrag: beingDragged: \(beingDragged)")
    
    
    if let proposed = proposed {
        log("onDragged: had proposed: \(proposed)")
        let updatedItem = masterList.items.first { $0.id == item.id }!
        masterList.items = moveItemIntoGroup(updatedItem,
                                             masterList.items,
                                             draggedAlong: draggedAlong,
                                             proposed)
    }

    // if no proposed group, then we moved item to top level:
    // 1. reset done-dragging item's x to `0`
    // 2. set item's parent to nil
    else {
        log("onDragged: no proposed group; will snap to top level")
        let updatedItem = masterList.items.first { $0.id == item.id }!
        masterList.items = moveItemToTopLevel(updatedItem,
                                              masterList.items,
                                              draggedAlong: draggedAlong)
    }

    return (masterList, proposed, beingDragged, cursorDrag)
}


func onDragEnded(_ item: RectItem,
                 _ items: RectItems,
                 draggedAlong: ItemIdSet,
                 proposed: ProposedGroup?) -> RectItems {
    
    print("onDragEnded called")
    var items = items
    
    // finalizes items' positions by index;
    // also updates itemns' previousPositions.
    items = setYPositionByIndices(items, isDragEnded: true)
//    print("onDragEnded: updated items: \(items)")
    
    let allDragged: ItemIds = [item.id] + Array(draggedAlong)
    
    // update both the X and Y in the previousLocation of the items that were moved;
    // ie `item` AND every id in `draggedAlong`
    for draggedId in allDragged {
        var draggedItem = retrieveItem(draggedId, items)
        draggedItem.previousLocation = draggedItem.location
        items = updateItem(draggedItem, items)
    }
    
//    print("onDragEnded: final items by color: \(items.map(\.color))")
//    print("onDragEnded: final items by location.x: \(items.map(\.location.x))")
    return items
}



// // MARK: VIEWS



// view closed
let CHEVRON_GROUP_TOGGLE_ICON =  "chevron.right"

struct RectViewChevron: View {
    
    let isClosed: Bool
    
    var body: some View {
        
        let rotationZ: CGFloat = isClosed ? 0 : 90
        
        Image(systemName: CHEVRON_GROUP_TOGGLE_ICON)
            .rotation3DEffect(Angle(degrees: rotationZ),
                              axis: (x: 0, y: 0, z: rotationZ))
            .animation(.default, value: isClosed)
    }
}

struct RectView2: View {
    
    var item: RectItem
    @Binding var masterList: MasterList // all items + groups
//    @Binding var current: ItemId?
    @Binding var current: BeingDraggedItem?
    @Binding var proposedGroup: ProposedGroup?
    @Binding var cursorDrag: CursorDrag?
    
    var isClosed: Bool
    
    var useLocation: Bool = true
    
    @State var isBeingEdited = false
    
    var body: some View {
        rectangle
    }
    
    var rectangle: some View {
                
        let isBeingDraggedColor: Color = (current.map { $0.current == item.id } ?? false) ? .white : .clear
        
        let isProposedGroupColor: Color = (proposedGroup?.parentId == item.id) ? .white : .clear
        
        return Rectangle().fill(item.color)
            .border(isBeingDraggedColor, width: 16)
            .overlay(isProposedGroupColor.opacity(0.8))
            .frame(width: RECT_WIDTH,
                   height: RECT_HEIGHT)
            .overlay(
                HStack {
                    VStack {
                        Text("Id: \(item.id.value)")
                        Text("Parent?: \(item.parentId?.value.description ?? "None")")
                    }
                }
                    .scaleEffect(1.4)
            )
            .border(.orange)
            .overlay(alignment: .trailing, content: {
                HStack {
                    if hasChildren(item.id, masterList) {
                        RectViewChevron(isClosed: isClosed)
                            .padding()
                            .onTapGesture {
                                log("onTap...")
                                if isClosed {
                                    masterList = onGroupOpened(openedId: item.id, masterList)
                                } else {
                                    masterList = onGroupClosed(closedId: item.id, masterList)
                                }
                            }
                    }
                    
                    Group {
                        if isBeingEdited {
                            Image(systemName: "circle")
                            Image(systemName: "circle")
                        }
                    }
                    .transition(AnyTransition
                                    .opacity
                                    .combined(with: .move(edge: .trailing)))
                } // HStack
                .animation(.default,
                           value: isBeingEdited)
                
                .padding()
            })
        
//            .offset(CGSize(width: item.location.x,
//                           height: item.location.y))
        
            .offset(CGSize(width: useLocation ? item.location.x : 0,
//            .offset(CGSize(width: item.location.x,
                           height: useLocation ? item.location.y : 0))
            
            
            .foregroundColor(.white)
        
            .onTapGesture(perform: {
                isBeingEdited.toggle()
            })
        
            .gesture(DragGesture()
                        .onChanged({ value in
                print("onChanged: \(item.id)")
                var item = item
                item.zIndex = 9999

                let (newMasterList, proposed, beingDragged, newCursorDrag) = onDragged(
                    item, // this dragged item
                    value.translation, // drag data
                    // ALL items
                    masterList)
                
                current = beingDragged
                masterList = newMasterList
                proposedGroup = proposed
                cursorDrag = newCursorDrag
            })
                        .onEnded({ _ in
                print("onEnded: \(item.id)")
                var item = item
                item.previousLocation = item.location
                item.zIndex = 0 // set to zero when drag ended
                
                let index = masterList.items.firstIndex { $0.id == item.id }!
                masterList.items[index] = item
                
                masterList.items = onDragEnded(
                    item,
                    masterList.items,
                    // MUST have a `current`
                    draggedAlong: current!.draggedAlong,
                    proposed: proposedGroup)
                
                log("Inside view, onDragEnded just run: items: \(masterList.items.map(\.color))")
                
                // also reset the potentially highlighted group
                proposedGroup = nil
                // and reset current dragging item
                current = nil
                cursorDrag = nil
                
            })
            ) // gesture
    }
}

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
//        list
        nativeList
            .frame(width: nativeListWidth)
//            .frame(width: 400, height: 900)
        
//            .frame(width: 400)
//            .animation(.default, value: masterList)
//            .offset(x: -200, y: -500)

        
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
                
//                let parent = d.parentId
//                let parentPosition = parent
//                    .map { retrieveItem($0, masterList.items) }?.location.y ?? d.location.y
//
//                let closedParentId = ItemId(1)
//
//                let parentY = retrieveItem(
//                    closedParentId, masterList.items).location.y
//
                RectView2(item: d,
                          masterList: $masterList,
                          current: $current,
                          proposedGroup: $proposedGroup,
                          cursorDrag: $cursorDrag,
                          isClosed: isClosed)
                
//                    .transition(.slide)
//                    .transition(.move(edge: .top))
                
//                    .transition(
////                        AnyTransition.opacity
//                        AnyTransition
//                         // move to the position of the closed or open parent?
//                            .offset(CGSize(width: 0,
////                                           height: -500))
////                                           height: -parentPosition))
//                                           height: -parentY))
//
//                            .combined(with: .opacity)
//                            .combined(with: .move(edge: .top))
//
//                    ) // .transition
            
                
                    .zIndex(Double(d.zIndex))
                
                
            } // ForEach
        } // ZStack
    }
    
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
//        MyColor(color: .gray),
    ]),
    MyColor(color: .green)
]

//let sampleColors4: [MyColor] = [
//    MyColor(color: .red),
//    MyColor(color: .blue, children: [
//        MyColor(color: .black),
//        MyColor(color: .brown, children: [
//            MyColor(color: .cyan),
//            MyColor(color: .purple)
//
//        ]),
//        MyColor(color: .indigo, children: [
//            MyColor(color: .orange),
//            MyColor(color: .gray),
//        ]),
//    ]),
//    MyColor(color: .green),
//    MyColor(color: .yellow)
//]

let sampleColors4: [MyColor] = [
    MyColor(color: .red),
    MyColor(color: .blue, children: [

        MyColor(color: .black),
        MyColor(color: .indigo),

        MyColor(color: .brown, children: [
            MyColor(color: .cyan),
            MyColor(color: .orange),
        ]),
    ]),
    MyColor(color: .green),
    MyColor(color: .yellow)
]

func generateData() -> MasterList {
    MasterList.fromColors(
        sampleColors0
//        sampleColors1
//        sampleColors2
//        sampleColors3
//        sampleColors4
    )
}



struct ContentView: View {
    
    @State var fakeSwipeId: Int? = 1
    
    @State var id: Int = Int.random(in: 0..<9999)
        
    var body: some View {
//        DragListView()
//        SwipeView(id: 1,
//                  activeSwipeId: $fakeSwipeId)
//            .offset(y: -300)
        SwipeListView().id(id)
            .overlay {
            Text("RESET").onTapGesture {
                id = Int.random(in: 0..<9999)
            }
            .scaleEffect(1.5)
            .offset(x: 400, y: -50)
        }
    }
    
}
