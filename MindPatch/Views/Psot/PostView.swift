import SwiftUI

struct PostView: View {
    @EnvironmentObject var blockStore: BlockStore
    let post: Block
    let boardBlock: Block?
    @Binding var focusedBlockId: UUID?
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDuplicate: (Block) -> Void

    private var blocksForPost: [Block] {
        blockStore.blocks.filter { $0.postId == post.id }
    }

    @State private var isPresentingEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                if let boardBlock {
                    Board(block: boardBlock).iconImage
                        .resizable()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                }

                HStack(alignment: .center, spacing: 4) {
                    TextField("ポストの内容", text: Binding(
                        get: { post.content },
                        set: { newValue in
                            var updated = post
                            updated.content = newValue
                            blockStore.replace(updated)
                        })
                    )
                    .font(.title2)
                    .bold()
                    .simultaneousGesture(TapGesture().onEnded { focusedBlockId = post.id })
                    .onSubmit { addBlockFromTitle() }

                    Text((post.createdAt ?? Date()).formatted(.dateTime.year().month().day().hour().minute()))
                        .font(.caption)
                        .foregroundColor(.gray)

                    Spacer()

                    Menu {
                        Button("編集") {
                            isPresentingEditor = true
                        }
                        Button("削除", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .padding(.top, 4)
                    }
                }
            }

            BlockEditorView(
                postId: post.id,
                focusedBlockId: $focusedBlockId,
                onDuplicate: onDuplicate,
                onDelete: { _ in
                    onDelete()
                    blockStore.saveBlocks()
                }
            )

            Divider()
        }
        .padding(.horizontal)
        .sheet(isPresented: $isPresentingEditor) {
            PostEditorView(
                post: post,
                boardBlock: boardBlock,
                onSave: { _, _ in
                    blockStore.saveBlocks()
                    isPresentingEditor = false
                }
            )
        }
    }

    func insertNewBlockBelow(_ id: UUID) -> UUID? {
        guard let currentIdx = blockStore.index(of: id),
              blockStore.blocks[currentIdx].postId == post.id else { return nil }
        let current = blockStore.blocks[currentIdx]
        var newBlock = blockStore.createBlock(for: post.id, type: current.type)
        newBlock.order = current.order + 1
        blockStore.replace(newBlock)
        return newBlock.id
    }

    private func addBlockFromTitle() {
        // Persist the latest title text
        blockStore.replace(post)
        // Create a block right under the title and focus it
        let newBlock = blockStore.createBlockAtStart(for: post.id, type: .text)
        focusedBlockId = newBlock.id
        blockStore.saveBlocks()
    }

    func indentBlock(_ id: UUID) {
        guard let idx = blockStore.index(of: id),
              blockStore.blocks[idx].postId == post.id,
              let prevIdx = blockStore.blocks[..<idx].lastIndex(where: { $0.postId == post.id })
        else { return }
        let prev = blockStore.blocks[prevIdx]
        blockStore.setParent(of: id, to: prev.id)
    }

    func outdentBlock(_ id: UUID) {
        guard let _ = blockStore.index(of: id) else { return }
        blockStore.setParent(of: id, to: nil)
    }

    func calculateIndentLevel(for block: Block) -> Int {
        var level = 0
        var current = block
        while let pid = current.parentId,
              let parent = blocksForPost.first(where: { $0.id == pid }) {
            level += 1
            current = parent
        }
        return level
    }
}
