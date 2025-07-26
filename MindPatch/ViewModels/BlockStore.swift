

import Foundation
import Combine

class BlockStore: ObservableObject {
    @Published var blocks: [Block] = []

    init() {
        // 仮のテストデータ
        let now = Date()
        blocks = [
            Block(id: UUID().uuidString, type: .text, content: "はじめのブロック", parentId: nil, postId: nil, boardId: nil, order: 10, createdAt: now, updatedAt: now, status: "draft", tags: nil, isPinned: false, isCollapsed: false, style: nil, props: nil),
            Block(id: UUID().uuidString, type: .text, content: "2つ目のブロック", parentId: nil, postId: nil, boardId: nil, order: 20, createdAt: now, updatedAt: now, status: "draft", tags: nil, isPinned: false, isCollapsed: false, style: nil, props: nil)
        ]
    }

    func addBlock(content: String, parentId: String? = nil) {
        let now = Date()
        let newBlock = Block(
            id: UUID().uuidString,
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

    func updateBlock(id: String, newContent: String) {
        if let index = blocks.firstIndex(where: { $0.id == id }) {
            blocks[index].content = newContent
            blocks[index].updatedAt = Date()
        }
    }

    func deleteBlock(id: String) {
        blocks.removeAll { $0.id == id }
    }
}
