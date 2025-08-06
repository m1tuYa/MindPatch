import Foundation

struct BlockRepository {
    static func loadBlocks() -> [Block] {
        guard let url = Bundle.main.url(forResource: "sampleBlockData", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else {
            print("Failed to load sampleBlockData.json")
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let rawBlocks = try? decoder.decode([Block].self, from: data) else {
            print("Failed to decode sampleBlockData.json")
            return []
        }

        var processedBlocks = rawBlocks.map { block in
            var b = block
            if b.id == UUID(uuidString: "00000000-0000-0000-0000-000000000000") { b.id = UUID() }
            if b.content.isEmpty { b.content = "" }
            if b.order < 0 { b.order = 0 }
            if b.boardId == nil { b.boardId = Block.unassignedBoardId }
            if b.postId == nil { b.postId = Block.unassignedPostId }
            if b.createdAt == nil { b.createdAt = Date() }
            if b.updatedAt == nil { b.updatedAt = Date() }
            if b.type == .numberedList && b.listGroupId == nil {
                b.listGroupId = UUID()
            }
            return b
        }

        // Ensure unassigned board exists
        if !processedBlocks.contains(where: { $0.id == Block.unassignedBoardId && $0.type == .board }) {
            processedBlocks.append(Block.unassignedBoard())
        }

        // Ensure unassigned post exists
        if !processedBlocks.contains(where: { $0.id == Block.unassignedPostId && $0.type == .post }) {
            processedBlocks.append(Block.unassignedPost(forBoard: Block.unassignedBoardId))
        }

        return processedBlocks
    }
}
