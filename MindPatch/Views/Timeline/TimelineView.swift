import SwiftUI
import Foundation

struct TimelineView: View {
    let board: Board?
    @State private var blocks: [Block] = []
    @State private var focusedBlockId: UUID? = nil

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                postList
            }
        }
        .navigationTitle(board?.title ?? "Timeline")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Add block action here if needed
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            blocks = BlockRepository.loadBlocks()
        }
    }

    private var postList: some View {
        ForEach(postsToDisplay(), id: \.id) { post in
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        if let boardBlock = boardBlock(for: post.boardId) {
                            Board(block: boardBlock).iconImage
                                .resizable()
                                .frame(width: 28, height: 28)
                                .clipShape(Circle())
                        }

                        HStack(alignment: .center, spacing: 4) {
                            TextField("ポストの内容", text: Binding(
                                get: { post.content },
                                set: { newValue in
                                    if let index = blocks.firstIndex(where: { $0.id == post.id }) {
                                        blocks[index].content = newValue
                                    }
                                })
                            )
                            .font(.title2)
                            .bold()

                            Text((post.createdAt ?? Date()).formatted(.dateTime.year().month().day().hour().minute()))
                                .font(.caption)
                                .foregroundColor(.gray)

                            Spacer()

                            Image(systemName: "ellipsis")
                                .padding(.top, 4)
                        }
                    }

                    ForEach(Array(blocksForPost(post.id).enumerated()), id: \.1.id) { index, block in
                        BlockView(
                            block: Binding(
                                get: {
                                    if let i = blocks.firstIndex(where: { $0.id == block.id }) {
                                        return blocks[i]
                                    } else {
                                        return block
                                    }
                                },
                                set: { newValue in
                                    if let i = blocks.firstIndex(where: { $0.id == block.id }) {
                                        blocks[i] = newValue
                                    }
                                }
                            ),
                            index: index,
                            indentLevel: 0,
                            focusedBlockId: $focusedBlockId,
                            onDelete: { id in
                                blocks.removeAll { $0.id == id }
                            },
                            onDuplicate: { blk in
                                var duplicatedBlock = blk
                                duplicatedBlock.id = UUID()
                                blocks.insert(duplicatedBlock, at: index + 1)
                            }
                        )
                        .id(block.id) // Ensure SwiftUI recognizes identity changes for focused updates
                    }

                    Divider()
                }
                .padding(.horizontal)
            }
        }
    }

    private func postsToDisplay() -> [Block] {
        blocks.filter { $0.type == .post && (board == nil || $0.boardId == board!.id) }
    }

    private func blocksForPost(_ postId: UUID) -> [Block] {
        blocks.filter { $0.postId == postId && $0.type != .post && $0.type != .board }
    }

    private func boardBlock(for boardId: UUID?) -> Block? {
        guard let boardId = boardId else { return nil }
        return blocks.first { $0.id == boardId && $0.type == .board }
    }
}
