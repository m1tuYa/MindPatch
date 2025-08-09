private struct _ViewFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}
private extension View {
    func _onGlobalFrameChange(_ handler: @escaping (CGRect) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: _ViewFrameKey.self, value: proxy.frame(in: .global))
            }
        )
        .onPreferenceChange(_ViewFrameKey.self, perform: handler)
    }
}

import SwiftUI

struct PostView: View {
    @EnvironmentObject var blockStore: BlockStore
    // @Environment(\.safeAreaInsets) private var safeAreaInsets

    let post: Block
    let boardBlock: Block?
    @Binding var focusedBlockId: UUID?
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDuplicate: (Block) -> Void

    // Derived
    private var blocksForPost: [Block] {
        blockStore.blocks.filter { $0.postId == post.id }
    }
    private var availableBoards: [Board] {
        blockStore.blocks
            .filter { $0.type == .board }
            .map { Board(block: $0) }
    }

    @State private var isPresentingEditor = false
    @State private var showBoardPopover = false
    @State private var boardIconFrame: CGRect = .zero
    private let topThreshold: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

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
            .environmentObject(blockStore)
        }
    }

    // MARK: - Subviews
    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Button { showBoardPopover.toggle() } label: {
                (boardBlock.map { Board(block: $0).iconImage } ?? Image(systemName: "folder"))
                    .resizable()
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
            }
            ._onGlobalFrameChange { rect in
                boardIconFrame = rect
            }
            .popover(
                isPresented: $showBoardPopover,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: (boardIconFrame.minY < topThreshold ? .top : .bottom)
            ) {
                BoardPickerPopover(
                    post: post,
                    onPicked: { boardId in
                        assignPostAndBlocks(to: boardId)
                        showBoardPopover = false
                    }
                )
                .environmentObject(blockStore)
                .frame(minWidth: 260)
                .padding(.vertical, 8)
            }

            HStack(alignment: .center, spacing: 4) {
                TextField(
                    "ポストの内容",
                    text: Binding(
                        get: { post.content },
                        set: { newValue in
                            var updated = post
                            updated.content = newValue
                            blockStore.replace(updated)
                        }
                    )
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
                    Button("編集") { isPresentingEditor = true }
                    Button("削除", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis").padding(.top, 4)
                }
            }
        }
    }





    private func addBlockFromTitle() {
        // Persist the latest title text
        blockStore.replace(post)
        // Create a block right under the title and focus it
        let newBlock = blockStore.createBlockAtStart(for: post.id, type: .text)
        focusedBlockId = newBlock.id
        blockStore.saveBlocks()
    }

    private func assignPostAndBlocks(to boardId: UUID) {
        if let idx = blockStore.index(of: post.id) {
            var updated = blockStore.blocks[idx]
            updated.boardId = boardId
            blockStore.replace(updated)
        }
        let targetIds = blockStore.blocks
            .filter { $0.postId == post.id }
            .map { $0.id }
        for bid in targetIds {
            if let bidx = blockStore.index(of: bid) {
                var b = blockStore.blocks[bidx]
                b.boardId = boardId
                blockStore.replace(b)
            }
        }
        blockStore.saveBlocks()
    }
}

private struct BoardPickerPopover: View {
    @EnvironmentObject var blockStore: BlockStore
    let post: Block
    let onPicked: (UUID) -> Void

    @State private var editingBoardId: UUID?
    @FocusState private var focusedBoardTitleId: UUID?

    private var availableBoards: [Board] {
        blockStore.blocks
            .filter { $0.type == .board }
            .map { Board(block: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(availableBoards) { board in
                HStack(spacing: 8) {
                    board.iconImage
                        .resizable()
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())

                    if editingBoardId == board.id {
                        TextField(
                            "ボード名",
                            text: Binding(
                                get: {
                                    if let idx = blockStore.index(of: board.id) {
                                        return blockStore.blocks[idx].content
                                    }
                                    return board.title
                                },
                                set: { newValue in
                                    if let idx = blockStore.index(of: board.id) {
                                        var b = blockStore.blocks[idx]
                                        b.content = newValue
                                        blockStore.replace(b)
                                    }
                                }
                            )
                        )
                        .focused($focusedBoardTitleId, equals: board.id)
                        .onAppear { focusedBoardTitleId = board.id }
                    } else {
                        Text(board.title)
                            .onTapGesture {
                                onPicked(board.id)
                            }
                    }
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.secondarySystemBackground))
                        .opacity(0.0001)
                )
            }

            Divider().padding(.vertical, 4)

            Button {
                let newId = createBoardAndBeginEditing()
                if let bid = newId {
                    // 生成直後にこのポストへ関連付けも行う
                    onPicked(bid)
                    editingBoardId = bid
                    focusedBoardTitleId = bid
                }
            } label: {
                Label("新規ボード", systemImage: "plus")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 4)
    }

    private func createBoardAndBeginEditing() -> UUID? {
        let board = Block(
            id: UUID(),
            type: .board,
            content: "新規ボード",
            parentId: nil,
            postId: nil,
            boardId: nil,
            order: 0
        )
        blockStore.add(board)
        blockStore.saveBlocks()
        return board.id
    }
}

