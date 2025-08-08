import SwiftUI

struct ContentView: View {
    @State private var selectedBoard: Board? = nil
    @StateObject private var blockStore = BlockStore()

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedBoard: $selectedBoard)
        } detail: {
            TimelineView(board: selectedBoard, blockStore: blockStore)
        }
        .onAppear {
            // Removed debug print statement
        }
    }
}
