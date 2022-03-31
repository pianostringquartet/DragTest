import SwiftUI


// // MARK: CONSTANTS

// was:
//let RECT_HEIGHT: CGFloat = 100

// now
let RECT_HEIGHT: CGFloat = CGFloat(VIEW_HEIGHT)


let RECT_WIDTH: CGFloat = 400
//let RECT_WIDTH: CGFloat = 200

//let VIEW_HEIGHT: Int = 200

// original testing height
let VIEW_HEIGHT: Int = 100

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



struct ContentView: View {
    
    @State var fakeSwipeId: Int? = 1
    
    @State var id: Int = Int.random(in: 0..<9999)
        
    var body: some View {
        
        DragListView()
        
//        SwipeView(id: 1,
//                  activeSwipeId: $fakeSwipeId)
//            .offset(y: -300)
        
//        SwipeListView().id(id)
//            .overlay {
//            Text("RESET").onTapGesture {
//                id = Int.random(in: 0..<9999)
//            }
//            .scaleEffect(1.5)
//            .offset(x: 400, y: -50)
//        }
        
    }
    
}

