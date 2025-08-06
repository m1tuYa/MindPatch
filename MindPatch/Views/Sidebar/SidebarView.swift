import SwiftUI

struct SidebarView: View {
    @Binding var selectedBoard: Board?
    @State private var boards: [Board] = []

    var body: some View {
        List(selection: $selectedBoard) {
            Text("📌 ホーム（全て表示）")
                .tag(Optional<Board>.none)

            ForEach(boards) { board in
                HStack(spacing: 4) {
                    board.iconImage
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text(board.title)
                }
                .tag(Optional(board))
            }
        }
        .navigationTitle("Boards")
        .onAppear {
            let allBlocks = BlockRepository.loadBlocks()
            self.boards = allBlocks
                .filter { $0.type == .board && $0.id != Block.unassignedBoardId }
                .map { Board(block: $0) }
        }
    }
}
