import Foundation
import Combine

class BlockStore: ObservableObject {
    @Published var blocks: [Block] = []

    init() {
        loadBlocks()
    }

    func loadBlocks() {
        if let savedBlocks = BlockRepository.loadBlocksFromDocumentDirectory() {
            self.blocks = savedBlocks
        } else {
            self.blocks = BlockRepository.loadBlocks()
            BlockRepository.saveBlocksToDocumentDirectory(self.blocks)
        }
    }

    func saveBlocks() {
        BlockRepository.saveBlocksToDocumentDirectory(self.blocks)
    }

    func addBlock(content: String, parentId: UUID? = nil) {
        let now = Date()
        let newBlock = Block(
            id: UUID(),
            type: .text,
            content: content,
            parentId: parentId,
            postId: nil,
            boardId: nil,
            order: (blocks.map { $0.order }.max() ?? 0) + 10,
            createdAt: now,
            updatedAt: now,
            status: "draft",
            tags: nil,
            isPinned: false,
            isCollapsed: false,
            style: nil,
            props: nil
        )
        blocks.append(newBlock)
        saveBlocks()
    }

    func deleteBlock(id: UUID) {
        blocks.removeAll { $0.id == id }
        saveBlocks()
    }
}
