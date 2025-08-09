import SwiftUI
import PencilKit

struct PostEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var blockStore: BlockStore
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

    private var blocksForPost: [Block] {
        blockStore.blocks.filter { $0.postId == post.id }
    }

    var body: some View {
        return NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 8) {
                        if let boardBlock {
                            Board(block: boardBlock).iconImage
                                .resizable()
                                .frame(width: 28, height: 28)
                                .clipShape(Circle())
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
                                .onChange(of: focusedBlockId) { _, newId in
                                    titleFocusedInternal = (newId == post.id)
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
