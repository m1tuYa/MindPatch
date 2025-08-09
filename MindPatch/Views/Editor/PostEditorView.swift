import SwiftUI
import PencilKit

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

struct PostEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var blockStore: BlockStore
    // @Environment(\.safeAreaInsets) private var safeAreaInsets
    @State var post: Block
    /// 新規ポスト作成遷移かどうか（既存編集のときは false のまま）
    let isNew: Bool
    let boardBlock: Block?
    let onSave: (Block, [Block]) -> Void

    init(
        post: Block,
        isNew: Bool = false,
        boardBlock: Block?,
        onSave: @escaping (Block, [Block]) -> Void
    ) {
        self._post = State(initialValue: post)
        self.isNew = isNew
        self.boardBlock = boardBlock
        self.onSave = onSave
    }

    @State private var focusedBlockId: UUID?
    @State private var isHandwritingMode = false
    @State private var canvasView = PKCanvasView()
    @FocusState private var titleFocusedInternal: Bool

    @State private var showBoardPopover = false
    @State private var boardIconFrame: CGRect = .zero

    private let topThreshold: CGFloat = 120

    // MARK: - Unified block insertion entrypoints
    private enum AddTrigger { case titleEnter, emptyTap, plusButton }

    /// タイトル Enter / 空白タップ / プラスボタン すべての入口をここに集約
    private func addBlock(trigger: AddTrigger) {
        // 新規ポスト作成時にタイトルへフォーカスしている場合、必要ならポストを先に保存
        if trigger == .titleEnter || trigger == .emptyTap { persistPost() }

        // 1) タイトルにフォーカスしているなら、最初のブロックを作る or 末尾へフォーカス移動
        if focusedBlockId == post.id {
            if blocksForPost.isEmpty {
                // 先頭へ 1 つ作成してそこへフォーカス
                let newBlock = blockStore.createBlockAtStart(for: post.id, type: .text)
                focusedBlockId = newBlock.id
            } else {
                // 既存がある場合は末尾へ移動
                focusedBlockId = blocksForPost.last?.id
            }
            blockStore.saveBlocks()
            return
        }

        // 2) いずれかのブロックにフォーカスしている場合は、その直下に挿入
        if let focusedId = focusedBlockId, let idx = blockStore.blocks.firstIndex(where: { $0.id == focusedId && $0.postId == post.id }) {
            let curr = blockStore.blocks[idx]
            let newBlock = Block(
                id: UUID(),
                type: curr.type,
                content: "",
                parentId: curr.parentId,
                postId: post.id,
                boardId: curr.boardId,
                order: curr.order + 1
            )
            blockStore.insert(newBlock, after: focusedId)
            focusedBlockId = newBlock.id
            blockStore.saveBlocks()
            return
        }

        // 3) 何もフォーカスがないときは、末尾に 1 つ作る（なければ先頭を作る）
        if let last = blocksForPost.last {
            let newBlock = Block(
                id: UUID(),
                type: .text,
                content: "",
                parentId: last.parentId,
                postId: post.id,
                boardId: last.boardId,
                order: last.order + 1
            )
            blockStore.insert(newBlock, after: last.id)
            focusedBlockId = newBlock.id
            blockStore.saveBlocks()
        } else {
            let newBlock = blockStore.createBlock(for: post.id, type: .text)
            focusedBlockId = newBlock.id
            blockStore.saveBlocks()
        }
    }

    /// 現在のポスト内容を BlockStore に反映して保存
    private func persistPost() {
        // BlockStore に同一 ID のエントリがあれば置き換えて保存
        blockStore.replace(post)
        blockStore.saveBlocks()
    }

    private var availableBoards: [Board] {
        blockStore.blocks
            .filter { $0.type == .board }
            .map { Board(block: $0) }
    }

    private func assignPostAndBlocks(to boardId: UUID) {
        // update local state first
        post.boardId = boardId
        blockStore.replace(post)
        // update blocks under this post
        let ids = blockStore.blocks.filter { $0.postId == post.id }.map { $0.id }
        for id in ids {
            if let idx = blockStore.index(of: id) {
                var b = blockStore.blocks[idx]
                b.boardId = boardId
                blockStore.replace(b)
            }
        }
        blockStore.saveBlocks()
      }

    private func createBoard(title: String, iconUrl: String?) -> Block? {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let board = Block(
            id: UUID(),
            type: .board,
            content: title,
            parentId: nil,
            postId: nil,
            boardId: nil,
            order: 0
        )
        // If your Block supports props assignment for iconUrl, wire it here later.
        blockStore.add(board)
        blockStore.saveBlocks()
        return board
    }

    private var blocksForPost: [Block] {
        blockStore.blocks.filter { $0.postId == post.id }
    }

    var body: some View {
        return NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 8) {
                        Button {
                            showBoardPopover.toggle()
                        } label: {
                            if let boardBlock {
                                Board(block: boardBlock).iconImage
                                    .resizable()
                                    .frame(width: 28, height: 28)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "folder")
                                    .resizable()
                                    .frame(width: 28, height: 28)
                                    .clipShape(Circle())
                            }
                        }
                        ._onGlobalFrameChange { rect in
                            boardIconFrame = rect
                        }
                        .buttonStyle(.plain)
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
                            TextField("ポストの内容", text: $post.content, onEditingChanged: { editing in
                                if editing {
                                    focusedBlockId = post.id
                                }
                            })
                                .simultaneousGesture(TapGesture().onEnded { focusedBlockId = post.id })
                                .focused($titleFocusedInternal)
                                .onSubmit {
                                    addBlock(trigger: .titleEnter)
                                }
                                .font(.title2)
                                .bold()
                                .onChange(of: focusedBlockId) { _, newValue in
                                    titleFocusedInternal = (newValue == post.id)
                                }

                            Text((post.createdAt ?? Date()).formatted(.dateTime.year().month().day().hour().minute()))
                                .font(.caption)
                                .foregroundColor(.gray)

                            Spacer()

                            Menu {
                                Button("編集", action: {
                                    // 編集アクション（PostEditorなので空でOK）
                                })
                                Button("削除", role: .destructive, action: {
                                    // 削除アクション（必要であれば渡す）
                                })
                            } label: {
                                Image(systemName: "ellipsis")
                                    .padding(.top, 4)
                            }
                        }
                    }

                    BlockEditorView(
                        postId: post.id,
                        focusedBlockId: $focusedBlockId,
                        onDuplicate: { blk in
                            var duplicated = blk
                            duplicated.id = UUID()
                            blockStore.insert(duplicated, after: blk.id)
                            blockStore.saveBlocks()
                        },
                        onDelete: { id in
                            blockStore.deleteBlock(id: id)
                            let siblings = blockStore.blocks.filter { $0.postId == post.id }
                            focusedBlockId = siblings.dropLast().last?.id
                            blockStore.saveBlocks()
                        }
                    )

                    if !isHandwritingMode {
                        Spacer()
                            .frame(maxWidth: .infinity, minHeight: UIScreen.main.bounds.height)
                            .background(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                addBlock(trigger: .emptyTap)
                            }
                    }

                    if isHandwritingMode {
                        GeometryReader { geometry in
                            HStack(alignment: .center, spacing: 0) {
                                VStack {
                                    Color.clear
                                        .frame(width: 20)
                                        .padding(.trailing, 4)
                                }
                                HandwritingCanvasView(canvasView: $canvasView)
                                    .frame(width: geometry.size.width - 24, height: 400)
                            }
                        }
                        .frame(height: 400)
                    }

                    Spacer(minLength: 32)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    addBlock(trigger: .emptyTap)
                }
                .padding(.horizontal)
            }
            .onAppear {
                if isNew && blocksForPost.isEmpty {
                    focusedBlockId = post.id
                    titleFocusedInternal = true
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("ポスト") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        if isHandwritingMode && !canvasView.drawing.bounds.isEmpty {
                            let fullImage = canvasView.drawing.image(from: canvasView.bounds, scale: UIScreen.main.scale)
                            if let trimmed = trimBottomTransparent(from: fullImage) {
                                let filename = saveImageToDocuments(trimmed)
                                if let lastBlock = blocksForPost.last {
                                    let imageBlock = Block(
                                        id: UUID(),
                                        type: .image,
                                        content: filename,
                                        parentId: lastBlock.parentId,
                                        postId: lastBlock.postId,
                                        boardId: lastBlock.boardId,
                                        order: lastBlock.order + 1
                                    )
                                    blockStore.insert(imageBlock, after: lastBlock.id)
                                    blockStore.saveBlocks()
                                }
                            }
                            canvasView.drawing = PKDrawing()
                        }
                        persistPost()
                        onSave(post, blocksForPost)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        toggleHandwritingMode()
                    } label: {
                        Image(systemName: isHandwritingMode ? "pencil.slash" : "pencil")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        addBlock(trigger: .plusButton)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    // Helper methods for PostEditorView

    func insertNewBlockBelow(_ id: UUID) -> UUID? {
        guard let index = blockStore.blocks.firstIndex(where: { $0.id == id && $0.postId == post.id }) else { return nil }
        let current = blockStore.blocks[index]
        let newBlock = Block(
            id: UUID(),
            type: current.type,
            content: "",
            parentId: current.parentId,
            postId: post.id,
            boardId: current.boardId,
            order: current.order + 1
        )
        blockStore.insert(newBlock, after: id)
        blockStore.saveBlocks()
        return newBlock.id
    }

    func toggleHandwritingMode() {
        if isHandwritingMode {
            // ON → OFF: 保存処理
            let fullImage = canvasView.drawing.image(from: canvasView.bounds, scale: UIScreen.main.scale)
            if let trimmed = trimBottomTransparent(from: fullImage) {
                let filename = saveImageToDocuments(trimmed)
                if let lastBlock = blocksForPost.last {
                    let imageBlock = Block(
                        id: UUID(),
                        type: .image,
                        content: filename,
                        parentId: lastBlock.parentId,
                        postId: lastBlock.postId,
                        boardId: lastBlock.boardId,
                        order: lastBlock.order + 1
                    )
                    blockStore.insert(imageBlock, after: lastBlock.id)
                    blockStore.saveBlocks()
                }
            }
            canvasView.drawing = PKDrawing()
            isHandwritingMode = false
        } else {
            // OFF → ON: 表示処理
            isHandwritingMode = true
        }
    }

    func trimBottomTransparent(from image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        guard let dataProvider = cgImage.dataProvider else { return nil }
        guard let pixelData = dataProvider.data else { return nil }
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4

        var cropHeight = height
        outerLoop: for y in stride(from: height - 1, through: 0, by: -1) {
            for x in 0 ..< width {
                let pixelIndex = (y * width + x) * bytesPerPixel
                let alpha = data[pixelIndex + 3]
                if alpha != 0 {
                    break outerLoop
                }
            }
            cropHeight -= 1
        }

        let rect = CGRect(x: 0, y: 0, width: width, height: cropHeight)
        guard let croppedCgImage = cgImage.cropping(to: rect) else { return nil }
        return UIImage(cgImage: croppedCgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    func saveImageToDocuments(_ image: UIImage) -> String {
        let filename = UUID().uuidString + ".png"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
        if let data = image.pngData() {
            try? data.write(to: url)
        }
        return filename
    }
}

struct HandwritingCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = .clear
        canvasView.drawingPolicy = .anyInput
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
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
                            .onTapGesture { onPicked(board.id) }
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
