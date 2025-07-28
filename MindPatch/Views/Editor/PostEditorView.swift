import SwiftUI

struct PostEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State var post: Block
    @State var blocks: [Block]
    let boardBlock: Block?
    let onSave: (Block, [Block]) -> Void

    @State private var focusedBlockId: UUID?

    var body: some View {
        // Break up the complex ForEach expression to help type-checking
        let indexedBlocks = Array(blocks.enumerated())
        return NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        if let boardBlock {
                            Board(block: boardBlock).iconImage
                                .resizable()
                                .frame(width: 28, height: 28)
                                .clipShape(Circle())
                        }

                        HStack(alignment: .center, spacing: 4) {
                            TextField("ポストの内容", text: $post.content)
                                .font(.title2)
                                .bold()

                            Text((post.createdAt ?? Date()).formatted(.dateTime.year().month().day().hour().minute()))
                                .font(.caption)
                                .foregroundColor(.gray)

                            Spacer()

                            Menu {
                                Button("編集", action: {
                                    // ここに編集アクションを追加できます（今はPostEditorなので空でOK）
                                })
                                Button("削除", role: .destructive, action: {
                                    // 削除アクション（必要であれば渡す）
                                })
                            } label: {
                                Image(systemName: "ellipsis")
                                    .padding(.top, 4)
                            }
                        }
                    }

                    ForEach(indexedBlocks, id: \.1.id) { index, block in
                        BlockView(
                            block: Binding(
                                get: { blocks[index] },
                                set: { newValue in blocks[index] = newValue }
                            ),
                            index: index,
                            indentLevel: 0,
                            focusedBlockId: $focusedBlockId,
                            onDelete: { id in blocks.removeAll { $0.id == id } },
                            onDuplicate: { blk in
                                var duplicated = blk
                                duplicated.id = UUID()
                                blocks.insert(duplicated, at: index + 1)
                            },
                            onEnter: { _ in insertNewBlockBelow(block.id) }
                        )
                    }

                    Spacer(minLength: 32)
                }
                .padding(.horizontal)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("ポスト") {
                        onSave(post, blocks)
                        dismiss()
                    }
                }
            }
        }
    }

    func insertNewBlockBelow(_ id: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        let current = blocks[index]
        let newBlock = Block(
            id: UUID(),
            type: current.type,
            content: "",
            parentId: current.parentId,
            postId: current.postId,
            boardId: current.boardId,
            order: current.order + 1
        )
        blocks.insert(newBlock, at: index + 1)
    }
}
