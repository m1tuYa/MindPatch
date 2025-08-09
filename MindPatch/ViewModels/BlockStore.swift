import Foundation
import Combine
import SwiftUI

// MARK: - Repository abstraction (non-breaking)
// Use a new name to avoid collision with existing `BlockRepository` static helpers used elsewhere.
protocol BlocksRepository {
    func loadFromDocuments() -> [Block]?
    func loadSample() -> [Block]
    func saveToDocuments(_ blocks: [Block]) throws
    var documentFileURL: URL { get }
}

// Default JSON repository that reads/writes blockData.json atomically.
// Internally, it can still reuse existing static helpers if needed later.
struct JSONBlocksRepository: BlocksRepository {
    private let fm = FileManager.default

    var documentDirectoryURL: URL {
        fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    var documentFileURL: URL {
        documentDirectoryURL.appendingPathComponent("blockData.json")
    }
    private var sampleFileURL: URL? {
        // If you have a bundled sample file, adjust this as appropriate.
        // Fallback: nil -> callers should provide sample blocks programmatically.
        nil
    }

    func loadFromDocuments() -> [Block]? {
        guard fm.fileExists(atPath: documentFileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: documentFileURL)
            return try JSONDecoder().decode([Block].self, from: data)
        } catch {
            print("❌ JSONBlocksRepository.loadFromDocuments error:", error)
            return nil
        }
    }

    func loadSample() -> [Block] {
        // Try bundled sample JSON if present, otherwise fallback to existing static repository or minimal seed.
        if let sampleFileURL, let data = try? Data(contentsOf: sampleFileURL), let blocks = try? JSONDecoder().decode([Block].self, from: data) {
            return blocks
        }
        // Fallback: use existing static helpers if they exist, otherwise return empty.
        if let blocks = BlockRepository.loadBlocksFromDocumentDirectory() {
            return blocks
        } else {
            return BlockRepository.loadBlocks()
        }
    }

    func saveToDocuments(_ blocks: [Block]) throws {
        let data = try JSONEncoder().encode(blocks)
        // Atomic write: write to a temp file and replace
        let tmpURL = documentDirectoryURL.appendingPathComponent(UUID().uuidString + ".tmp")
        try data.write(to: tmpURL, options: .atomic)
        if fm.fileExists(atPath: documentFileURL.path) {
            _ = try fm.replaceItemAt(documentFileURL, withItemAt: tmpURL)
        } else {
            try fm.moveItem(at: tmpURL, to: documentFileURL)
        }
    }
}

// MARK: - Store
@MainActor
final class BlockStore: ObservableObject {
    @Published private(set) var blocks: [Block] = []

    private let repo: BlocksRepository
    private var saveWorkItem: DispatchWorkItem?

    init(repo: BlocksRepository = JSONBlocksRepository()) {
        self.repo = repo
        loadBlocks()
    }

    // MARK: Load / Save
    func loadBlocks() {
        if let saved = repo.loadFromDocuments() {
            self.blocks = saved
        } else {
            self.blocks = repo.loadSample()
            try? repo.saveToDocuments(self.blocks)
        }
    }

    func scheduleSave(after delay: TimeInterval = 0.5) {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.saveNow()
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func saveNow() {
        do {
            try repo.saveToDocuments(self.blocks)
        } catch {
            print("❌ BlockStore.saveNow failed:", error)
        }
    }

    // Backward-compatible callsite
    func saveBlocks() {
        scheduleSave()
    }

    // MARK: Query helpers
    func posts(boardId: UUID?) -> [Block] {
        // 「未所属ポスト」（システム予約のダミーポスト）は常に除外
        let allPosts = blocks.filter {
            $0.type == .post
            && $0.status != "system"
            && $0.id != Block.unassignedPostId
        }
        // boardId 指定時はそのボードのポストのみ、未指定なら全ボードの通常ポストを返す
        if let boardId = boardId {
            return allPosts.filter { $0.boardId == boardId }
        } else {
            return allPosts
        }
    }

    func blocks(for postId: UUID) -> [Block] {
        blocks.filter { $0.postId == postId && $0.type != .post && $0.type != .board }
    }

    func boardBlock(for boardId: UUID?) -> Block? {
        guard let boardId else { return nil }
        return blocks.first { $0.id == boardId && $0.type == .board }
    }

    func index(of id: UUID) -> Int? {
        blocks.firstIndex { $0.id == id }
    }

    func binding(for id: UUID) -> Binding<Block>? {
        guard let i = index(of: id) else { return nil }
        return Binding<Block>(
            get: { self.blocks[i] },
            set: { newValue in
                self.blocks[i] = newValue
                self.scheduleSave()
            }
        )
    }

    // MARK: Single-item helpers
    func add(_ block: Block) {
        blocks.append(block)
        scheduleSave()
    }

    func replace(_ block: Block) {
        if let i = index(of: block.id), i < blocks.count {
            blocks[i] = block
            scheduleSave()
        }
    }

    func remove(id: UUID) {
        blocks.removeAll { $0.id == id }
        scheduleSave()
    }

    // MARK: Mutations (consistency enforced here)
    @discardableResult
    func createPost(boardId: UUID?) -> Block {
        let now = Date()
        let post = Block(
            id: UUID(),
            type: .post,
            content: "",
            parentId: nil,
            postId: nil,
            boardId: boardId ?? Block.unassignedBoardId,
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
        blocks.append(post)
        scheduleSave()
        return post
    }

    @discardableResult
    func createBlock(for postId: UUID, type: BlockType = .text) -> Block {
        let now = Date()
        let block = Block(
            id: UUID(),
            type: type,
            content: "",
            parentId: nil,
            postId: postId,
            boardId: nil,
            order: (blocks.filter { $0.postId == postId }.map { $0.order }.max() ?? 0) + 10,
            createdAt: now,
            updatedAt: now,
            status: "draft",
            tags: nil,
            isPinned: false,
            isCollapsed: false,
            style: nil,
            props: nil
        )
        blocks.append(block)
        scheduleSave()
        return block
    }

    // Insert a block right after a target block id
    func insert(_ block: Block, after afterId: UUID) {
        if let idx = index(of: afterId) {
            blocks.insert(block, at: idx + 1)
            scheduleSave()
        }
    }

    // Insert as the first content block of a post
    func insertAtStart(_ block: Block, for postId: UUID) {
        if let firstIdx = blocks.firstIndex(where: { $0.postId == postId }) {
            blocks.insert(block, at: firstIdx)
        } else {
            blocks.append(block)
        }
        scheduleSave()
    }

    @discardableResult
    func createBlockAtStart(for postId: UUID, type: BlockType = .text) -> Block {
        let now = Date()
        let block = Block(
            id: UUID(),
            type: type,
            content: "",
            parentId: nil,
            postId: postId,
            boardId: nil,
            order: (blocks.filter { $0.postId == postId }.map { $0.order }.min() ?? 0) - 1,
            createdAt: now,
            updatedAt: now,
            status: "draft",
            tags: nil,
            isPinned: false,
            isCollapsed: false,
            style: nil,
            props: nil
        )
        insertAtStart(block, for: postId)
        return block
    }

    // Update parent relationship safely
    func setParent(of id: UUID, to parentId: UUID?) {
        if let idx = index(of: id) {
            blocks[idx].parentId = parentId
            scheduleSave()
        }
    }

    func deleteBlock(id: UUID) {
        remove(id: id)
    }
}
