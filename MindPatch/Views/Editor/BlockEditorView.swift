import SwiftUI

struct BlockEditorView: View {
    @EnvironmentObject var blockStore: BlockStore
    let postId: UUID
    @Binding var focusedBlockId: UUID?
    var onDuplicate: (Block) -> Void
    var onDelete: (UUID) -> Void

    @State private var moveCaretTarget: (id: UUID, pos: Int)?

    private var blocksForPost: [Block] {
        blockStore.blocks.filter { $0.postId == postId }
    }

    var body: some View {
        let blocks = blocksForPost
        VStack(alignment: .leading, spacing: 0) {
            blockList(blocks)
        }
        .onChange(of: focusedBlockId) { _, newId in
            handleFocusedChange(newId)
        }
    }

    // MARK: - List & Row builders
    @ViewBuilder
    private func blockList(_ blocks: [Block]) -> some View {
        ForEach(Array(blocks.enumerated()), id: \.element.id) { (localIndex, block) in
            row(for: block, localIndex: localIndex, blocks: blocks)
        }
    }

    @ViewBuilder
    private func row(for block: Block, localIndex: Int, blocks: [Block]) -> some View {
        let binding = Binding<Block>(
            get: { blockStore.blocks.first(where: { $0.id == block.id }) ?? block },
            set: { _ in /* no-op: BlockView pushes edits via BlockStore */ }
        )
        let movePosBinding = Binding<Int?>(
            get: { moveCaretTarget?.id == block.id ? moveCaretTarget?.pos : nil },
            set: { newValue in
                if newValue == nil, moveCaretTarget?.id == block.id {
                    // Defer state mutation to the next runloop to avoid
                    // "Modifying state during view update" warnings.
                    DispatchQueue.main.async {
                        if moveCaretTarget?.id == block.id {
                            moveCaretTarget = nil
                        }
                    }
                }
            }
        )
        BlockView(
            block: binding,
            index: localIndex + 1,
            indentLevel: calculateIndentLevel(for: block),
            moveCursorToPosition: movePosBinding,
            focusedBlockId: $focusedBlockId,
            onDelete: { id in
                onDelete(id)
                blockStore.saveBlocks()
            },
            onDuplicate: { blk in onDuplicate(blk) },
            onEnter: { id in
                if let newId = insertNewBlockBelow(id) {
                    focusedBlockId = newId
                    blockStore.saveBlocks()
                }
            },
            onShiftEnter: { id in
                if let idx = blockStore.index(of: id) {
                    var b = blockStore.blocks[idx]
                    b.content.append("\n")
                    blockStore.replace(b)
                    blockStore.saveBlocks()
                }
            },
            onTab: { id in indentBlock(id) },
            onShiftTab: { id in outdentBlock(id) },
            onDeleteEmpty: {
                handleDeleteEmpty(block: block, localIndex: localIndex)
            },
            onSplitBlock: { before, after in
                handleSplit(block: block, before: before, after: after)
            },
            onMergeOrDelete: { isEmpty in
                handleMergeOrDelete(block: block, isEmpty: isEmpty)
            }
        )
    }

    // MARK: - Handlers
    private func handleFocusedChange(_ newId: UUID?) {
        guard let id = newId else { return }
        if let target = moveCaretTarget, target.id == id { return }
        guard let b = blockStore.blocks.first(where: { $0.id == id }) else { return }
        let pos = b.content.isEmpty ? 0 : b.content.count
        moveCaretTarget = (id: id, pos: pos)
        DispatchQueue.main.async {
            if moveCaretTarget?.id == id { moveCaretTarget = nil }
        }
    }

    private func handleDeleteEmpty(block: Block, localIndex: Int) {
        blockStore.deleteBlock(id: block.id)
        let current = blockStore.blocks.filter { $0.postId == postId }
        let prev = localIndex > 0 ? current[localIndex - 1].id : current.first?.id
        if let prevId = prev {
            let endPos = blockStore.blocks.first(where: { $0.id == prevId })?.content.count ?? 0
            moveCaretTarget = (id: prevId, pos: endPos)
            focusedBlockId = prevId
            DispatchQueue.main.async { if moveCaretTarget?.id == prevId { moveCaretTarget = nil } }
        } else {
            focusedBlockId = nil
        }
        blockStore.saveBlocks()
    }

    private func handleSplit(block: Block, before: String, after: String) {
        guard blockStore.index(of: block.id) != nil else { return }
        var head = block
        head.content = before
        blockStore.replace(head)
        let tail = Block(
            id: UUID(),
            type: block.type,
            content: after,
            parentId: block.parentId,
            postId: block.postId,
            boardId: block.boardId,
            order: block.order + 1
        )
        blockStore.insert(tail, after: head.id)
        moveCaretTarget = (id: tail.id, pos: 0)
        focusedBlockId = tail.id
        DispatchQueue.main.async { if moveCaretTarget?.id == tail.id { moveCaretTarget = nil } }
        blockStore.saveBlocks()
    }

    private func handleMergeOrDelete(block: Block, isEmpty: Bool) {
        if let idx = blockStore.index(of: block.id), idx > 0 {
            let prevId = blockStore.blocks[idx - 1].id
            if isEmpty {
                blockStore.deleteBlock(id: block.id)
                let endPos = blockStore.blocks.first(where: { $0.id == prevId })?.content.count ?? 0
                moveCaretTarget = (id: prevId, pos: endPos)
                focusedBlockId = prevId
                DispatchQueue.main.async { if moveCaretTarget?.id == prevId { moveCaretTarget = nil } }
            } else {
                var prev = blockStore.blocks[idx - 1]
                let insertionPos = prev.content.count
                prev.content += block.content
                blockStore.replace(prev)
                blockStore.deleteBlock(id: block.id)
                moveCaretTarget = (id: prevId, pos: insertionPos)
                focusedBlockId = prevId
                DispatchQueue.main.async { if moveCaretTarget?.id == prevId { moveCaretTarget = nil } }
            }
            blockStore.saveBlocks()
        } else if isEmpty, blockStore.index(of: block.id) != nil {
            blockStore.deleteBlock(id: block.id)
            let current = blockStore.blocks.filter { $0.postId == postId }
            if let prevId = current.first?.id {
                let endPos = blockStore.blocks.first(where: { $0.id == prevId })?.content.count ?? 0
                moveCaretTarget = (id: prevId, pos: endPos)
                focusedBlockId = prevId
                DispatchQueue.main.async { if moveCaretTarget?.id == prevId { moveCaretTarget = nil } }
            } else {
                focusedBlockId = nil
            }
            blockStore.saveBlocks()
        }
    }

    // MARK: - Operations
    private func insertNewBlockBelow(_ id: UUID) -> UUID? {
        guard let idx = blockStore.blocks.firstIndex(where: { $0.id == id && $0.postId == postId }) else { return nil }
        let current = blockStore.blocks[idx]
        let newBlock = Block(
            id: UUID(),
            type: current.type,
            content: "",
            parentId: current.parentId,
            postId: postId,
            boardId: current.boardId,
            order: current.order + 1
        )
        blockStore.insert(newBlock, after: id)
        return newBlock.id
    }

    private func indentBlock(_ id: UUID) {
        guard
            let idx = blockStore.blocks.firstIndex(where: { $0.id == id && $0.postId == postId }),
            let prevIdx = blockStore.blocks[..<idx].lastIndex(where: { $0.postId == postId })
        else { return }
        let prev = blockStore.blocks[prevIdx]
        blockStore.setParent(of: id, to: prev.id)
        blockStore.saveBlocks()
    }

    private func outdentBlock(_ id: UUID) {
        blockStore.setParent(of: id, to: nil)
        blockStore.saveBlocks()
    }

    private func calculateIndentLevel(for block: Block) -> Int {
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
