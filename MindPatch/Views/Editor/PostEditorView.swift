import SwiftUI
import PencilKit

struct PostEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State var post: Block
    @State var blocks: [Block]
    let boardBlock: Block?
    let onSave: (Block, [Block]) -> Void

    @State private var focusedBlockId: UUID?
    @State private var isHandwritingMode = false
    @State private var savedHandwritingImage: UIImage?
    @State private var canvasView = PKCanvasView()

    var body: some View {
        // Break up the complex ForEach expression to help type-checking
        let indexedBlocks = Array(blocks.enumerated())
        return NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        if let boardBlock {
                            Board(block: boardBlock).iconImage
                                .resizable()
                                .frame(width: 28, height: 28)
                                .clipShape(Circle())
                        }

                        HStack(alignment: .center, spacing: 4) {
                            TextField("ポストの内容", text: $post.content)
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

                    ForEach(indexedBlocks, id: \.1.id) { index, block in
                        BlockView(
                            block: Binding(
                                get: { blocks[index] },
                                set: { newValue in blocks[index] = newValue }
                            ),
                            index: index,
                            indentLevel: 0,
                            focusedBlockId: $focusedBlockId,
                            onDelete: { id in blocks.removeAll { $0.id == id } },
                            onDuplicate: { blk in
                                var duplicated = blk
                                duplicated.id = UUID()
                                blocks.insert(duplicated, at: index + 1)
                            },
                            onEnter: { _ in insertNewBlockBelow(block.id) }
                        )
                    }

                    if isHandwritingMode {
                        HandwritingCanvasView(canvasView: $canvasView)
                            .frame(height: 400)
                    }
                    if let img = savedHandwritingImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                    }

                    Spacer(minLength: 32)
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
                        onSave(post, blocks)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        toggleHandwritingMode()
                    } label: {
                        Image(systemName: isHandwritingMode ? "pencil.slash" : "pencil")
                    }
                }
            }
        }
    }

    func insertNewBlockBelow(_ id: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
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
    }

    func toggleHandwritingMode() {
        if isHandwritingMode {
            // ON → OFF: 保存処理
            let image = canvasView.drawing.image(from: canvasView.bounds, scale: UIScreen.main.scale)
            if let trimmed = trimBottomTransparent(from: image) {
                savedHandwritingImage = trimmed
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
