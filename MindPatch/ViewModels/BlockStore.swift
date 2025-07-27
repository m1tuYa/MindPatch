import Foundation
import Combine

class BlockStore: ObservableObject {
    @Published var blocks: [Block] = []

    init() {
        loadSample()
    }

    func loadSample() {
        self.blocks = BlockRepository.loadBlocks()
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
    }

    func updateBlock(id: UUID, newContent: String) {
        if let index = blocks.firstIndex(where: { $0.id == id }) {
            blocks[index].content = newContent
            blocks[index].updatedAt = Date()
        }
    }

    func deleteBlock(id: UUID) {
        blocks.removeAll { $0.id == id }
    }
}
