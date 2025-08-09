import SwiftUI
import Foundation

struct TimelineView: View {
    let board: Board?
    @EnvironmentObject var blockStore: BlockStore
    @State private var focusedBlockId: UUID? = nil
    @State private var isPresentingPostEditor = false
    @State private var draftPost = Block.emptyPost()

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    postList
                }
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        let newPost = blockStore.createPost(boardId: board?.id)
                        draftPost = newPost
                        isPresentingPostEditor = true
                    }) {
                        Image(systemName: "plus")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(board?.title ?? "Timeline")
        .toolbar { }
        .sheet(isPresented: $isPresentingPostEditor) {
            ZStack {
                Color.white.ignoresSafeArea()
                PostEditorView(
                    post: draftPost,
                    isNew: true,
                    boardBlock: boardBlock(for: draftPost.boardId),
                    onSave: { _, _ in blockStore.saveBlocks() }
                )
            }
        }
    }

    private var postList: some View {
        ForEach(postsToDisplay(), id: \.id) { post in
            PostView(
                post: post,
                boardBlock: boardBlock(for: post.boardId),
                focusedBlockId: $focusedBlockId,
                onEdit: { },
                onDelete: {
                    blockStore.remove(id: post.id)
                },
                onDuplicate: { duplicated in
                    var newBlock = duplicated
                    newBlock.id = UUID()
                    blockStore.add(newBlock)
                }
            )
        }
    }

    private func postsToDisplay() -> [Block] {
        blockStore.posts(boardId: board?.id)
    }

    private func blocksForPost(_ postId: UUID) -> [Block] {
        blockStore.blocks(for: postId)
    }

    private func boardBlock(for boardId: UUID?) -> Block? {
        blockStore.boardBlock(for: boardId)
    }
}
