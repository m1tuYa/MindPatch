import SwiftUI
import PencilKit

struct PostEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var post: Block
    @State var blocks: [Block]
    let boardBlock: Block?
    let onSave: (Block, [Block]) -> Void

    @State private var focusedBlockId: UUID?
    @State private var isHandwritingMode = false
    @State private var canvasView = PKCanvasView()
    

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
                                    focusedBlockId = nil
                                }
                            })
                                .font(.title2)
                                .bold()

                            Text((post.createdAt ?? Date()).formatted(.dateTime.year().month().day().hour().minute()))
                                .font(.caption)
                                .foregroundColor(.gray)

                            Spacer()

                            Menu {
                                Button("編集", action: {
                                    // ここに編集アクションを追加できます（今はPostEditorなので空でOK）
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
                        blocks: $blocks,
                        focusedBlockId: $focusedBlockId,
                        updateBlock: { updated in
                            // Match PostView behavior: let BlockEditorView handle updating the @Binding blocks directly
                            // This closure can be used for persistence if needed, but should not replace the whole struct in array
                        },
                        onDuplicate: { blk in
                            var duplicated = blk
                            duplicated.id = UUID()
                            if let idx = blocks.firstIndex(where: { $0.id == blk.id }) {
                                blocks.insert(duplicated, at: idx + 1)
                            } else {
                                blocks.append(duplicated)
                            }
                        },
                        onDelete: { id in
                            if let idx = blocks.firstIndex(where: { $0.id == id }) {
                                blocks.remove(at: idx)
                                if idx > 0 {
                                    focusedBlockId = blocks[idx - 1].id
                                } else if !blocks.isEmpty {
                                    focusedBlockId = blocks.first?.id
                                } else {
                                    focusedBlockId = nil
                                }
                            }
                        }
                    )

                    if !isHandwritingMode {
                        Spacer()
                            .frame(maxWidth: .infinity, minHeight: UIScreen.main.bounds.height)
                            .background(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let lastBlock = blocks.last {
                                    focusedBlockId = lastBlock.id
                                    // Move cursor to the end of the last block's text
                                    if let idx = blocks.firstIndex(where: { $0.id == lastBlock.id }) {
                                        // Force SwiftUI to update binding so that cursor goes to end
                                        var updated = blocks[idx]
                                        updated.content = blocks[idx].content // no change, just trigger focus
                                        blocks[idx] = updated
                                    }
                                }
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
                    if let lastBlock = blocks.last {
                        focusedBlockId = lastBlock.id
                    }
                }
                .padding(.horizontal)
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
                        updateBlock()
                        if isHandwritingMode && !canvasView.drawing.bounds.isEmpty {
                            let fullImage = canvasView.drawing.image(from: canvasView.bounds, scale: UIScreen.main.scale)
                            if let trimmed = trimBottomTransparent(from: fullImage) {
                                let filename = saveImageToDocuments(trimmed)
                                if let lastBlock = blocks.last {
                                    let imageBlock = Block(
                                        id: UUID(),
                                        type: .image,
                                        content: filename,
                                        parentId: lastBlock.parentId,
                                        postId: lastBlock.postId,
                                        boardId: lastBlock.boardId,
                                        order: lastBlock.order + 1
                                    )
                                    blocks.append(imageBlock)
                                }
                            }
                            canvasView.drawing = PKDrawing()
                        }
                        onSave(post, blocks)
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
                        updateBlock()
                        addNewBlockAction()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    func insertNewBlockBelow(_ id: UUID) -> UUID? {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return nil }
        let current = blocks[index]
        let newBlockId = UUID()
        let newBlock = Block(
            id: newBlockId,
            type: current.type,
            content: "",
            parentId: current.parentId,
            postId: current.postId,
            boardId: current.boardId,
            order: current.order + 1
        )
        blocks.insert(newBlock, at: index + 1)
        return newBlockId
    }

    func toggleHandwritingMode() {
        updateBlock()
        if isHandwritingMode {
            // ON → OFF: 保存処理
            let fullImage = canvasView.drawing.image(from: canvasView.bounds, scale: UIScreen.main.scale)
            if let trimmed = trimBottomTransparent(from: fullImage) {
                let filename = saveImageToDocuments(trimmed)
                if let lastBlock = blocks.last {
                    let imageBlock = Block(
                        id: UUID(),
                        type: .image,
                        content: filename,
                        parentId: lastBlock.parentId,
                        postId: lastBlock.postId,
                        boardId: lastBlock.boardId,
                        order: lastBlock.order + 1
                    )
                    blocks.append(imageBlock)
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

    /// Adds a new block below the focused block or as appropriate for handwriting mode.
    func addNewBlockAction() {
        if !isHandwritingMode {
            if let focusedId = focusedBlockId {
                // Insert new block below focused block with placeholder text
                guard let index = blocks.firstIndex(where: { $0.id == focusedId }) else { return }
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
                focusedBlockId = newBlock.id
            } else {
                // Append a new text block with placeholder text at the end and focus it
                let lastBlock = blocks.last
                let newBlock = Block(
                    id: UUID(),
                    type: .text,
                    content: "新規ブロック",
                    parentId: lastBlock?.parentId,
                    postId: lastBlock?.postId,
                    boardId: lastBlock?.boardId,
                    order: (lastBlock?.order ?? 0) + 1
                )
                blocks.append(newBlock)
                focusedBlockId = newBlock.id
            }
        } else if isHandwritingMode {
            // Save current canvas as image block, clear canvas, then insert a new text block after the image block, and show fresh canvas
            let fullImage = canvasView.drawing.image(from: canvasView.bounds, scale: UIScreen.main.scale)
            if let trimmed = trimBottomTransparent(from: fullImage) {
                let filename = saveImageToDocuments(trimmed)
                // Add image block at the end
                let lastBlock = blocks.last
                let imageBlock = Block(
                    id: UUID(),
                    type: .image,
                    content: filename,
                    parentId: lastBlock?.parentId,
                    postId: lastBlock?.postId,
                    boardId: lastBlock?.boardId,
                    order: (lastBlock?.order ?? 0) + 1
                )
                blocks.append(imageBlock)
                // Clear canvas for next input
                canvasView.drawing = PKDrawing()
                // Insert a new text block after the image block
                let textBlock = Block(
                    id: UUID(),
                    type: .text,
                    content: "",
                    parentId: imageBlock.parentId,
                    postId: imageBlock.postId,
                    boardId: imageBlock.boardId,
                    order: imageBlock.order + 1
                )
                blocks.append(textBlock)
                // Set focus to the new text block
                focusedBlockId = textBlock.id
            }
        }
    }

    func updateBlock() {
        if let id = focusedBlockId, let index = blocks.firstIndex(where: { $0.id == id }) {
            let original = blocks[index]
            blocks[index] = Block(
                id: original.id,
                type: original.type,
                content: original.content,
                parentId: original.parentId,
                postId: original.postId,
                boardId: original.boardId,
                order: original.order
            )
        }
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
