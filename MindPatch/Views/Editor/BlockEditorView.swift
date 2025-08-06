import SwiftUI

struct BlockEditorView: View {
    @Binding var blocks: [Block]
    @Binding var focusedBlockId: UUID?
    var updateBlock: (Block) -> Void
    var onDuplicate: (Block) -> Void
    var onDelete: (UUID) -> Void

    var body: some View {
        ForEach(Array(blocks.enumerated()), id: \.1.id) { index, block in
            BlockView(
                block: Binding(
                    get: { blocks[index] },
                    set: { newValue in updateBlock(newValue) }
                ),
                index: index,
                indentLevel: calculateIndentLevel(for: block),
                focusedBlockId: $focusedBlockId,
                onDelete: { id in onDelete(id) },
                onDuplicate: { blk in onDuplicate(blk) },
                onEnter: { id in
                    if let newId = insertNewBlockBelow(id) {
                        focusedBlockId = newId
                    }
                },
                onShiftEnter: { id in updateBlockContentWithNewline(id) },
                onTab: { id in indentBlock(id) },
                onShiftTab: { id in outdentBlock(id) },
                onDeleteEmpty: {
                    // Delete current block and focus previous block
                    blocks.removeAll { $0.id == block.id }
                    if index > 0 {
                        focusedBlockId = blocks[index - 1].id
                    } else if !blocks.isEmpty {
                        focusedBlockId = blocks.first?.id
                    } else {
                        focusedBlockId = nil
                    }
                },
                onSplitBlock: { before, after in
                    blocks[index].content = before
                    updateBlock(blocks[index])
                    let newBlock = Block(
                        id: UUID(),
                        type: block.type,
                        content: after,
                        parentId: block.parentId,
                        postId: block.postId,
                        boardId: block.boardId,
                        order: block.order + 1
                    )
                    blocks.insert(newBlock, at: index + 1)
                    focusedBlockId = newBlock.id
                },
                onMergeOrDelete: { isEmpty in
                    if index > 0 {
                        let previousId = blocks[index - 1].id
                        if isEmpty {
                            // Delete current block
                            blocks.remove(at: index)
                            focusedBlockId = previousId
                        } else {
                            // Merge current block's text into previous block
                            blocks[index - 1].content += blocks[index].content
                            updateBlock(blocks[index - 1])
                            blocks.remove(at: index)
                            focusedBlockId = previousId
                        }
                    } else {
                        // First block: just delete if empty
                        if isEmpty {
                            blocks.remove(at: index)
                            focusedBlockId = blocks.first?.id
                        }
                    }
                }
            )
        }
    }

    private func insertNewBlockBelow(_ id: UUID) -> UUID? {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return nil }
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
        return newBlock.id
    }

    private func updateBlockContentWithNewline(_ id: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks[index].content.append("\n")
    }

    private func indentBlock(_ id: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }), index > 0 else { return }
        let previous = blocks[index - 1]
        blocks[index].parentId = previous.id
    }

    private func outdentBlock(_ id: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks[index].parentId = nil
    }

    private func calculateIndentLevel(for block: Block) -> Int {
        var level = 0
        var current = block
        while let parentId = current.parentId,
              let parent = blocks.first(where: { $0.id == parentId }) {
            level += 1
            current = parent
        }
        return level
    }
}
