import SwiftUI

struct PostView: View {
    let post: Block
    let boardBlock: Block?
    @State private var blocks: [Block]
    @Binding var focusedBlockId: UUID?
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDuplicate: (Block) -> Void
    let saveBlocks: () -> Void

    public init(
        post: Block,
        boardBlock: Block?,
        blocks: [Block],
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        focusedBlockId: Binding<UUID?>,
        onDuplicate: @escaping (Block) -> Void,
        saveBlocks: @escaping () -> Void
    ) {
        self.post = post
        self.boardBlock = boardBlock
        _blocks = State(initialValue: blocks)
        self.onEdit = onEdit
        self.onDelete = onDelete
        self._focusedBlockId = focusedBlockId
        self.onDuplicate = onDuplicate
        self.saveBlocks = saveBlocks
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
                            try? saveBlocks()
                        })
                    )
                    .font(.title2)
                    .bold()

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
                blocks: $blocks,
                focusedBlockId: $focusedBlockId,
                onDuplicate: onDuplicate,
                onDelete: { _ in
                    onDelete()
                    saveBlocks()
                },
                saveBlocks: saveBlocks
            )

            Divider()
        }
        .padding(.horizontal)
        .sheet(isPresented: $isPresentingEditor) {
            PostEditorView(
                post: post,
                blocks: blocks,
                boardBlock: boardBlock,
                onSave: { _, _ in
                    saveBlocks()
                    isPresentingEditor = false
                },
                saveBlocks: saveBlocks
            )
        }
    }

    func insertNewBlockBelow(_ id: UUID) -> UUID? {
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

    func indentBlock(_ id: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }), index > 0 else { return }
        let previous = blocks[index - 1]
        blocks[index].parentId = previous.id
    }

    func outdentBlock(_ id: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks[index].parentId = nil
    }
    
    func calculateIndentLevel(for block: Block) -> Int {
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
