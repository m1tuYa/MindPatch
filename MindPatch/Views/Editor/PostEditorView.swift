import SwiftUI

struct PostEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State var post: Block
    @State var blocks: [Block]
    let boardBlock: Block?
    let onSave: (Block, [Block]) -> Void

    @State private var focusedBlockId: UUID?

    var body: some View {
        NavigationView {
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
                        }
                    }

                    ForEach(Array(blocks.enumerated()), id: \.1.id) { index, block in
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
                            }
                        )
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
            }
        }
    }
}
