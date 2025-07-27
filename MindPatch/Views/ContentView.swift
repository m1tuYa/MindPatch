import SwiftUI

struct ContentView: View {
    @State private var selectedBoard: Board? = nil

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedBoard: $selectedBoard)
        } detail: {
            TimelineView(board: selectedBoard)
        }
    }
}
