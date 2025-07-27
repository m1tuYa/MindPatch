import SwiftUI

struct PostView: View {
    let post: Block
    let boardBlock: Block?
    let blocks: [Block]
    let onEdit: () -> Void
    let onDelete: () -> Void
    let focusedBlockId: UUID?
    let updateBlock: (Block) -> Void
    let onDuplicate: (Block) -> Void

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
                            updateBlock(updated)
                        })
                    )
                    .font(.title2)
                    .bold()

                    Text((post.createdAt ?? Date()).formatted(.dateTime.year().month().day().hour().minute()))
                        .font(.caption)
                        .foregroundColor(.gray)

                    Spacer()

                    Menu {
                        Button("編集", action: onEdit)
                        Button("削除", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .padding(.top, 4)
                    }
                }
            }

            ForEach(Array(blocks.enumerated()), id: \.1.id) { index, block in
                BlockView(
                    block: Binding(
                        get: { block },
                        set: { newValue in updateBlock(newValue) }
                    ),
                    index: index,
                    indentLevel: 0,
                    focusedBlockId: .constant(focusedBlockId),
                    onDelete: { id in onDelete() },
                    onDuplicate: { blk in onDuplicate(blk) }
                )
            }

            Divider()
        }
        .padding(.horizontal)
    }
}
