//
//  File.swift
//  DragTest
//
//  Created by Christian J Clampitt on 3/31/22.
//

import Foundation
import SwiftUI

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


// the highest index we can have moved an item to;
// based on item count but with special considerations
// for whether we're dragging a group.
func getMaxMovedToIndex(item: RectItem,
                        items: RectItems,
                        draggedAlong: ItemIdSet) -> Int {
    
    var maxIndex = items.count - 1
    
    // special case: when moving a group,
    // ignore the children we're dragging along
    if item.isGroup {
        let itemsWithoutDraggedAlong = items.filter { x in !draggedAlong.contains(x.id) }
            maxIndex = itemsWithoutDraggedAlong.count - 1
    }
    return maxIndex
}

    
func getMovedtoIndex(item: RectItem,
                     items: RectItems,
                     draggedAlong: ItemIdSet,
                     maxIndex: Int,
                     movingDown: Bool) -> Int {

    var maxIndex = items.count - 1

//    log("getMovedtoIndex: item: \(item.id) is group?: \(item.isGroup)")

    // special case:
    // if we moved a parent to the end of the items (minus parents' own children),
    // then don't adjust-by-indices while dragging.
    if item.isGroup {

        let itemsWithoutDraggedAlong = items.filter { x in !draggedAlong.contains(x.id) }

//            print("getMovedtoIndex: special case maxIndex: \(maxIndex)")
            maxIndex = itemsWithoutDraggedAlong.count - 1
    }

    let maxY = maxIndex * VIEW_HEIGHT

//    print("getMovedtoIndex: item: \(item)")
//    print("getMovedtoIndex: maxY: \(maxY)")
//    print("getMovedtoIndex: movingDown: \(movingDown)")

    // no, needs to be by steps of 100
    // otherwise 0...800 will be 800 numbers

//    let range = (0...maxY).reversed().filter { $0.isMultiple(of: VIEW_HEIGHT) }
    var range = (0...maxY)
        .filter { $0.isMultiple(of: VIEW_HEIGHT / 2) }

    range.append(range.last! + VIEW_HEIGHT/2 )

    if movingDown {
        range = range.reversed()
    }

//    print("getMovedtoIndex: range: \(range)")
//    print("getMovedtoIndex: item.location.y: \(item.location.y)")

    // try to find the highest threshold we (our item's location.y) satisfy
    for threshold in range {

        // for moving up, want to find the first threshold we UNDERSHOOT
        // where range is (0, 50, 150, ..., 250)

        // for moving down, want to find the first treshold we OVERSHOOT
        // where range is (250, ..., 150, 50, 0)

        let foundThreshold = movingDown
            ? item.location.y > CGFloat(threshold)
            : item.location.y < CGFloat(threshold)

//        if item.location.y > CGFloat(threshold) {
        if foundThreshold {

//            print("getMovedtoIndex: found at threshold: \(threshold)")

            // still use the threshold, but now eg have to round up or down?

            // eg we were at 100; now at 49; so we me

            let j = (CGFloat(threshold)/CGFloat(VIEW_HEIGHT))
//            print("getMovedtoIndex: j: \(j)")
            var k = j
//            k.round(.toNearestOrAwayFromZero)

            // if we're moving the item down,
            // then we'll want to round up the threshold
            if movingDown {
                k.round(.up)
            } else {
                k.round(.down)
            }

//            print("getMovedtoIndex: k: \(k)")
//            print("getMovedtoIndex: k as int: \(Int(k))")

//            let i = threshold/VIEW_HEIGHT

//            print("getMovedtoIndex: i: \(i)")
//            return i

            // NEVER RETURN AN INDEX HIGHER THAN MAX-INDEX
            let ki = Int(k)
            if ki > maxIndex {
                return maxIndex
            } else {
                return ki
            }
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


// TODO: should be incorporated into `getMovedtoIndex`?
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

struct OnItemDraggedResult {
    let masterList: MasterList
    let proposed: ProposedGroup?
    let beingDragged: BeingDraggedItem
    let cursorDrag: CursorDrag
}

// When dragging: set actively-dragged and dragged-along items' z-indices to be high
// When drag ended: set all items z-indices = 0
func updateZIndices(_ items: RectItems,
                       zIndex: Int) -> RectItems {
    items.map {
        var item = $0
        item.zIndex = zIndex
        return item
    }
}

let CUSTOM_LIST_ITEM_MAX_Z_INDEX = 9999
let CUSTOM_LIST_ITEM_MIN_Z_INDEX = 0

func updateAllZIndices(items: RectItems,
                       itemId: ItemId,
                       draggedAlong: ItemIdSet) -> RectItems {
    
    var items = items
    
    let updatedItems = updateZIndices(
        items.filter {
            ($0.id == itemId) || draggedAlong.contains($0.id)
        },
        zIndex: CUSTOM_LIST_ITEM_MAX_Z_INDEX)
    
    for updatedItem in updatedItems {
        items = updateItem(updatedItem, items)
    }
    
    return items
}

func setItemsInGroupOrTopLevel(item: RectItem,
                               masterList: MasterList,
                               draggedAlong: ItemIdSet,
                               cursorDrag: CursorDrag) -> OnItemDraggedResult {
    
    var masterList = masterList
    
    // set all dragged items' z-indices to max
    masterList.items = updateAllZIndices(
        items: masterList.items, itemId:
            item.id, draggedAlong:
            draggedAlong)
    
    let proposed = proposeGroup(
        item,
        masterList,
        draggedAlong.count,
        cursorDrag: cursorDrag)
    
    let beingDragged = BeingDraggedItem(current: item.id,
                                        draggedAlong: draggedAlong)
    
    log("setItemsInGroupOrTopLevel: beingDragged: \(beingDragged)")
    
    
    
    
    if let proposed = proposed {
        log("setItemsInGroupOrTopLevel: had proposed: \(proposed)")
        masterList.items = moveItemIntoGroup(item,
                                 masterList.items,
                                 draggedAlong: draggedAlong,
                                 proposed)
    }
    
    // if no proposed group, then we moved item to top level:
    // 1. reset done-dragging item's x to `0`
    // 2. set item's parent to nil
    else {
        log("setItemsInGroupOrTopLevel: no proposed group; will snap to top level")
        masterList.items = moveItemToTopLevel(item,
                                  masterList.items,
                                  draggedAlong: draggedAlong)
    }
    
    return OnItemDraggedResult(masterList: masterList,
                               proposed: proposed,
                               beingDragged: beingDragged,
                               cursorDrag: cursorDrag)
}


// We've moved the item up or down (along with its children);
// did we move it enough to have a new index placement for it?
func calculateNewIndexOnDrag(item: RectItem,
                             items: RectItems,
                             draggedAlong: ItemIdSet,
                             movingDown: Bool,
                             originalItemIndex: Int,
                             movedIndices: [Int]) -> Int {
    
    let maxMovedToIndex = getMaxMovedToIndex(
        item: item,
        items: items,
        draggedAlong: draggedAlong)
    
    var calculatedIndex = getMovedtoIndex(
        item: item,
        items: items,
        draggedAlong: draggedAlong,
        maxIndex: maxMovedToIndex,
        movingDown: movingDown)
    
    
    print("calculateNewIndexOnDrag: originalItemIndex: \(originalItemIndex)")
    print("calculateNewIndexOnDrag: calculatedIndex was: \(calculatedIndex)")
    
    // Is this really correct?
    let maxIndex = items.count - 1
    
    // Can't this be combined with something else?
    calculatedIndex = adjustMoveToIndex(
        calculatedIndex: calculatedIndex,
        originalItemIndex: originalItemIndex,
        movedIndices: movedIndices,
        maxIndex: maxIndex)
    
    print("calculateNewIndexOnDrag: calculatedIndex is now: \(calculatedIndex)")
    
    return calculatedIndex
}


func maybeMoveIndices(originalItemId: ItemId,
                      _ items: RectItems,
                      indicesMoved: [Int],
                      to: Int,
                      originalIndex: Int) -> RectItems {
    
    log("maybeMoveIndices: originalItemId: \(originalItemId)")
    log("maybeMoveIndices: indicesMoved: \(indicesMoved)")
    log("maybeMoveIndices: to: \(to)") // ie calculatedIndex
    log("maybeMoveIndices: originalIndex: \(originalIndex)")
    
    var items = items
    
    if to != originalIndex {
        
        log("maybeMoveIndices: Will move...")
        
        /*
         listData.move(fromOffsets: IndexSet(integer: from),
         toOffset: to > from ? to + 1 : to)
         */
        
        log("maybeMoveIndices: items by id BEFORE move: \(items.map(\.id))")
        log("maybeMoveIndices: items by color BEFORE move: \(items.map(\.color))")
        
        let finalOffset = to > originalIndex ? to + 1 : to
        
        log("maybeMoveIndices: finalOffset: \(finalOffset)")
        
        items.move(fromOffsets: IndexSet(indicesMoved),
                   toOffset: finalOffset)
        
        log("maybeMoveIndices: items by id AFTER move: \(items.map(\.id))")
        
        log("maybeMoveIndices: items by color AFTER move: \(items.map(\.color))")
        
        items = setYPositionByIndices(
            originalItemId: originalItemId,
            items,
            isDragEnded: false)
        
        log("maybeMoveIndices: item ids after position reset by indices: \(items.map(\.id))")
        
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
    
//    log("groupFromChildBelow: item: \(item)")
    
    let movedItemIndex = item.itemIndex(items)
    let entireIndex = movedItemIndex + movedItemChildrenCount
    
    // must look at the index of the first item BELOW THE ENTIRE BEING-MOVED-ITEM-LIST
    let indexBelow: Int = entireIndex + 1
    
//    log("groupFromChildBelow: movedItemIndex: \(movedItemIndex)")
//    log("groupFromChildBelow: entireIndex: \(entireIndex)")
//    log("groupFromChildBelow: indexBelow: \(indexBelow)")
    // ^^ when you're dragging along eg
    
    guard let itemBelow = items[safeIndex: indexBelow] else {
//        log("groupFromChildBelow: no itemBelow")
        return nil
    }
    
    guard let parentOfItemBelow = itemBelow.parentId else {
//        log("groupFromChildBelow: no parent on itemBelow")
        return nil
    }
    
//    log("groupFromChildBelow: itemBelow: \(itemBelow)")
//    log("groupFromChildBelow: itemBelow.parentId: \(itemBelow.parentId)")
//    log("groupFromChildBelow: itemBelow.indentationLevel.value: \(itemBelow.indentationLevel.value)")
//    log("groupFromChildBelow: item.indentationLevel.value: \(item.indentationLevel.value)")
    
    let itemsAbove = getItemsAbove(item, items)
    
    guard let parentItemAbove = itemsAbove.first(where: { $0.id == parentOfItemBelow }) else {
//        log("groupFromChildBelow: could not find parent above")
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
//                       cursorDrag: CursorDrag) -> (ProposedGroup?, Bool) {
                       cursorDrag: CursorDrag) -> ProposedGroup? {
    
//    var proposed: ProposedGroup? = nil
    var proposals = [ProposedGroup]()
    
    log("findDeepestParent: item.id: \(item.id)")
    log("findDeepestParent: item.location.x: \(item.location.x)")
    log("findDeepestParent: cursorDrag: \(cursorDrag)")
    
    let items = masterList.items
    let excludedGroups = masterList.excludedGroups
    
    var itemLocationX = cursorDrag.x
    
    log("findDeepestParent: itemLocationX was: \(itemLocationX)")
    
    let maxIndentationLevel = IndentationLevel(3)
    
    log("findDeepestParent: maxIndentationLevel.toXLocation was: \(maxIndentationLevel.toXLocation)")
//
//    // If we're trying to give a group an identation level greater than 3,
//    // don't allow this
//    if itemLocationX >= maxIndentationLevel.toXLocation
//        && item.isGroup {
//        itemLocationX = maxIndentationLevel.dec().toXLocation // maxIndentationLevel.toXLocation - 1
//    }
    
//    if var _proposed = proposed,
//        _proposed.indentationLevel.value >= 3,
//       item.isGroup {
//        _proposed.xIndentation = _proposed.indentationLevel.dec().toXLocation
//        proposed = _proposed
//    }
    
    
    log("findDeepestParent: itemLocationX is now: \(itemLocationX)")
    
//    (proposed?.indentationLevel.value ?? 0) >= 3
    
    for itemAbove in getItemsAbove(item, items) {
        log("findDeepestParent: itemAbove.id: \(itemAbove.id)")
        log("findDeepestParent: itemAbove.location.x: \(itemAbove.location.x)")
        
        // ie is this dragged item at, or east of, the above item?
        if itemLocationX > itemAbove.location.x {
            // ^^ has to be >, not >=, because = is top level in some cases?
            
            let itemAboveHasChildren = hasChildren(itemAbove.id, masterList)
            
            // if the itemAbove us itself a parent,
            // then we want to put our being-dragged-item into that itemAbove's child list;
            // and NOT use that itemAbove's own parent as our group
            if itemAboveHasChildren,
               // make sure it's not a closed group that we're proposing!
               !excludedGroups[itemAbove.id].isDefined,
               // make sure the itemAbove is also a group!
               itemAbove.isGroup
            {
                log("found itemAbove that has children; will make being-dragged-item")
                let proposed = ProposedGroup(
                    parentId: itemAbove.id,
                    xIndentation: itemAbove.indentationLevel.inc().toXLocation)
                proposals.append(proposed)
            }
            
            // this can't quite be right --
            // eg we can find an item above us that has its own parent,
            // we'd wrongly put the being-dragged-item into
            
            else if let itemAboveParentId = itemAbove.parentId,
                    !excludedGroups[itemAboveParentId].isDefined {
                log("found itemAbove that is part of a group whose parent id is: \(itemAbove.parentId)")
                let proposed = ProposedGroup(
                    parentId: itemAboveParentId,
                    xIndentation: itemAbove.location.x)
                proposals.append(proposed)
            }

            // if the item above is NOT itself part of a group,
            // we'll just use the item above now as its parent
            else if !excludedGroups[itemAbove.id].isDefined,
                    itemAbove.isGroup {
                log("found itemAbove without parent")
                let proposed = ProposedGroup(
                    parentId: itemAbove.id,
                    xIndentation: IndentationLevel(1).toXLocation)
                proposals.append(proposed)
                // ^^^ if item has no parent ie is top level,
                // then need this indentation to be at least one level
            }
//            log("findDeepestParent: found proposed: \(proposed)")
//            log("findDeepestParent: ... for itemAbove: \(itemAbove.id)")
        } else {
            log("findDeepestParent: item \(item.id) was not at/east of itemAbove \(itemAbove.id)")
            
        }
    }
    
//    log("findDeepestParent: proposed: \(proposed)")
    log("findDeepestParent: proposals: \(proposals)")
    
//    if item.isGroup,
//       proposals.count > 1,
//       let deepestProposed = proposals.last,
////       deepestProposed.indentationLevel.value >= 3 {
//       deepestProposed.indentationLevel.value >= 3 {
//        proposals = proposals.dropLast()
//    }
    
//    if item.isGroup,
//       proposals.count > 1,
//       let deepestProposed = proposals.last {
//
//        log("deepestProposed.indentationLevel.value: \(deepestProposed.indentationLevel.value)")
//
//        if deepestProposed.indentationLevel.value >= 3 {
//            log("will drop last...")
////            let ks = proposals.dropLast()
////            log("will drop last... PROPOSALS NOW: \(ks)")
////            let k = ks.last
////            let k = proposals[proposals.count - 3]
//
//            // only look at groups with less than three indentation levels
//            let ks = proposals.filter { $0.indentationLevel.value < 3 }
//            log("will drop last... PROPOSALS NOW: \(ks)")
//            // and take the last one...
//            let k = ks.last
//
////            let k = proposals.dropLast(1).last
////            proposals.removeLast()
////            let k = proposals.last
//            log("will drop last... k: \(k)")
//            return (k, true)
////            return proposals.dropLast().last
//        }
//    }
    
    
//
//    // no no! can't just change it here, since that proposedGroup.parentId will be group!
//    if var _proposed = proposed,
//        _proposed.indentationLevel.value >= 3,
//       item.isGroup {
//        _proposed.xIndentation = _proposed.indentationLevel.dec().toXLocation
//        proposed = _proposed
//    }
    
    
//    if ((proposed?.indentationLevel.value ?? 0) >= 3)
//        && item.isGroup {
//        proposed?.indentationLevel = proposed?.indentationLevel.dec()
//    }
//    log("findDeepestParent: final proposed: \(proposed)")
    log("findDeepestParent: final proposals: \(proposals)")
    
//    return proposed
//    return (proposals.last, false)
    return proposals.last
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
//    var proposed: ProposedGroup? = nil
    var proposed = findDeepestParent(item,
//    let (deepestProposed, wasCurtailed) = findDeepestParent(item,
                                     masterList,
                                     cursorDrag: cursorDrag)
    
//    proposed = deepestProposed
    
    
    log("proposeGroup: proposed from trying to find deepest parent: \(proposed)")
    
    // Exceptions:
    
    // does the item have a non-parent top-level it immediately above it?
    // if so, that blocks group proposal
    if blockedByTopLevelItemImmediatelyAbove(item, items) {
        log("proposeGroup: blocked by non-parent top-level item above")
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
        
        log("proposeGroup: found group \(groupDueToChildBelow.parentId) from child below")
        
        // if our drag is east of the proposed-from-below's indentation level,
        // and we already found a proposed group from 'deepest parent',
        // then don't use proposed-from-below.
        let keepProposed = (groupDueToChildBelow.indentationLevel.toXLocation < cursorDrag.x) && proposed.isDefined
        
        if !keepProposed {
//            if !wasCurtailed {
                // don't propose a group from child below
                // if we curtailed the indentation
                proposed = groupDueToChildBelow
//            }
            
//            proposed = groupDueToChildBelow
        }
    }
    
//    log("proposeGroup: might return: \(proposed)")
    
    // don't limit it here -- limit it in findDeepestParent
//    if (proposed?.indentationLevel.value ?? 0) >= 3 {
//        log("proposeGroup: proposedParent was too deep \(proposed?.indentationLevel.value); resetting...")
//        proposed = nil
//    }
    
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
    log("moveItemIntoGroup: draggedAlong: \(draggedAlong)")
    
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
                          // the indentation level from the proposed group
                          // (if top level then = 0)
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
    
//    log("maybeSnapDescendants: startingIndentationLevel: \(startingIndentationLevel)")
//    log("maybeSnapDescendants: item.indentationLevel.value: \(item.indentationLevel.value)")
    
    let indentDiff: Int = startingIndentationLevel.value - item.indentationLevel.value
//    log("maybeSnapDescendants: indentDiff: \(indentDiff)")
    
    var items = items
    
    
    for child in descendants {
        
        log("on child: \(child.id)")
        
        var child = child
//        log("maybeSnapDescendants: child location BEFORE setXLocationByIndentation: \(child.location.x)")
        
        let childExistingIndent = child.indentationLevel.value
//        log("maybeSnapDescendants: childExistingIndent: \(childExistingIndent)")
        let newIndent = childExistingIndent + indentDiff
//        log("maybeSnapDescendants: newIndent: \(newIndent)")
        
        let finalChildIndent = IndentationLevel(newIndent)
//        log("maybeSnapDescendants: finalChildIndent: \(finalChildIndent)")
    
        child = setXLocationByIndentation(child, finalChildIndent)
        
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
func setYPositionByIndices(originalItemId: ItemId,
                           _ items: RectItems,
                           isDragEnded: Bool = false,
                           _ viewHeight: Int = 100) -> RectItems {
    
//    print("setYPositionByIndices: will adjust positions of items (by id): \(items.map(\.id))")
    
    return items.enumerated().map { (offset, item) in
        // need to keep the level of nesting, which never changes when reseting positions
        var item = item
        let newY = CGFloat(offset * viewHeight)
        
//        print("setYPositionByIndices: item id: \(item.id)")
//        print("setYPositionByIndices: newY: \(newY)")
        
        if !isDragEnded && item.id == originalItemId {
            print("setYPositionByIndices: will not change originalItemId \(originalItemId)'s y-position until drag-is-ended")
            return item
        }
        else {
            // Setting position by indices NEVER changes x location
            item.location.y = newY
            
            // ONLY SET `previousLocation.y` HERE
            if isDragEnded {
    //            print("setYPositionByIndices: drag ended, so resetting previous position")
                item.previousLocation.y = newY
            }
            return item
        }

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

//func onDragged(_ item: RectItem, // item being actively dragged
//               _ translation: CGSize,
//               _ masterList: MasterList) -> (MasterList,
//                                             ProposedGroup?,
//                                             BeingDraggedItem,
//                                             CursorDrag) {

// from `DragTest`
func onDragged(_ item: RectItem, // item being actively dragged
               _ translation: CGSize,
               _ masterList: MasterList) -> OnItemDraggedResult {

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
                
    let calculatedIndex = calculateNewIndexOnDrag(
        item: item,
        items: masterList.items,
        draggedAlong: draggedAlong,
        movingDown: translation.height > 0,
        originalItemIndex: originalItemIndex,
        movedIndices: newIndices)
        
    masterList.items = maybeMoveIndices(
        originalItemId: item.id,
        masterList.items,
        indicesMoved: newIndices,
        to: calculatedIndex,
        originalIndex: originalItemIndex)
    
    let updatedOriginalIndex = item.itemIndex(masterList.items)
    // update `item` again!
    item = masterList.items[updatedOriginalIndex]
        
    return setItemsInGroupOrTopLevel(
        item: item,
        masterList: masterList,
        draggedAlong: draggedAlong,
        cursorDrag: cursorDrag)
}


func onDragEnded(_ item: RectItem,
                 _ items: RectItems,
                 draggedAlong: ItemIdSet,
                 proposed: ProposedGroup?) -> RectItems {
    
    print("onDragEnded called")
    var items = items
    
    // finalizes items' positions by index;
    // also updates itemns' previousPositions.
    items = setYPositionByIndices(
        originalItemId: item.id,
        items,
        isDragEnded: true)
//    print("onDragEnded: updated items: \(items)")
    
    let allDragged: ItemIds = [item.id] + Array(draggedAlong)
    
    // update both the X and Y in the previousLocation of the items that were moved;
    // ie `item` AND every id in `draggedAlong`
    for draggedId in allDragged {
        var draggedItem = retrieveItem(draggedId, items)
        draggedItem.previousLocation = draggedItem.location
        items = updateItem(draggedItem, items)
    }
    
    // reset the z-indices
    items = updateZIndices(items, zIndex: 0)
    
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
//        rectangle
//        Text("love")
        rect2
    }
    
    var rect2: some View {
        
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
            .offset(x: item.location.x, y: item.location.y)
            .foregroundColor(Color.white)
            .onTapGesture(perform: {
                isBeingEdited.toggle()
            })
            .gesture(DragGesture()
                        .onChanged({ value in
                print("onChanged: \(item.id)")
                var item = item
                item.zIndex = 9999

//                let (newMasterList, proposed, beingDragged, newCursorDrag) = onDragged(
//                    item, // this dragged item
//                    value.translation, // drag data
//                    // ALL items
//                    masterList)
//                current = beingDragged
//                masterList = newMasterList
//                proposedGroup = proposed
//                cursorDrag = newCursorDrag
                
                let result = onDragged(
                    item, // this dragged item
                    value.translation, // drag data
                    // ALL items
                    masterList)

                current = result.beingDragged
                masterList = result.masterList
                proposedGroup = result.proposed
                cursorDrag = result.cursorDrag
                
                
                
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
    
//    var rectangle: some View {
//
////        let isBeingDraggedColor: Color = (current.map { $0.current == item.id } ?? false) ? .white : .clear
//
////        let isProposedGroupColor: Color = (proposedGroup?.parentId == item.id) ? .white : .clear
//
//        return Rectangle().fill(item.color)
//            .border(isBeingDraggedColor, width: 16)
//            .overlay(isProposedGroupColor.opacity(0.8))
//            .frame(width: RECT_WIDTH,
//                   height: RECT_HEIGHT)
//            .overlay(
//                HStack {
//                    VStack {
//                        Text("Id: \(item.id.value)")
//                        Text("Parent?: \(item.parentId?.value.description ?? "None")")
//                    }
//                }
//                    .scaleEffect(1.4)
//            )
//            .border(.orange)
//            .overlay(alignment: .trailing, content: {
//                HStack {
//                    if hasChildren(item.id, masterList) {
//                        RectViewChevron(isClosed: isClosed)
//                            .padding()
//                            .onTapGesture {
//                                log("onTap...")
//                                if isClosed {
//                                    masterList = onGroupOpened(openedId: item.id, masterList)
//                                } else {
//                                    masterList = onGroupClosed(closedId: item.id, masterList)
//                                }
//                            }
//                    }
//
//                    Group {
//                        if isBeingEdited {
//                            Image(systemName: "circle")
//                            Image(systemName: "circle")
//                        }
//                    }
//                    .transition(AnyTransition
//                                    .opacity
//                                    .combined(with: .move(edge: .trailing)))
//                } // HStack
//                .animation(.default,
//                           value: isBeingEdited)
//
//                .padding()
//            })
//
//            .offset(x: item.location.x, y: item.location.y)
//
////            .offset(CGSize(width: item.location.x,
////                           height: item.location.y))
//
////            .offset(CGSize(width: useLocation ? item.location.x : 0,
////            .offset(CGSize(width: item.location.x,
//                           /
//
//
////            .foregroundColor(Color.white)
//
//            .onTapGesture(perform: {
//                isBeingEdited.toggle()
//            })
//
//            .gesture(DragGesture()
//                        .onChanged({ value in
//                print("onChanged: \(item.id)")
//                var item = item
//                item.zIndex = 9999
//
//                let (newMasterList, proposed, beingDragged, newCursorDrag) = onDragged(
//                    item, // this dragged item
//                    value.translation, // drag data
//                    // ALL items
//                    masterList)
//
//                current = beingDragged
//                masterList = newMasterList
//                proposedGroup = proposed
//                cursorDrag = newCursorDrag
//            })
//                        .onEnded({ _ in
//                print("onEnded: \(item.id)")
//                var item = item
//                item.previousLocation = item.location
//                item.zIndex = 0 // set to zero when drag ended
//
//                let index = masterList.items.firstIndex { $0.id == item.id }!
//                masterList.items[index] = item
//
//                masterList.items = onDragEnded(
//                    item,
//                    masterList.items,
//                    // MUST have a `current`
//                    draggedAlong: current!.draggedAlong,
//                    proposed: proposedGroup)
//
//                log("Inside view, onDragEnded just run: items: \(masterList.items.map(\.color))")
//
//                // also reset the potentially highlighted group
//                proposedGroup = nil
//                // and reset current dragging item
//                current = nil
//                cursorDrag = nil
//
//            })
//            ) // gesture
//    }
}

