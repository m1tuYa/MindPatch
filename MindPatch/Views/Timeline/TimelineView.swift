import SwiftUI
import Foundation

struct TimelineView: View {
    let board: Board?
    @ObservedObject var blockStore: BlockStore
    @State private var focusedBlockId: UUID? = nil
    @State private var isPresentingPostEditor = false
    @State private var draftPost = Block.emptyPost()
    @State private var draftBlocks: [Block] = [Block.emptyTextBlock(postId: Block.unassignedPostId)]

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
                        draftPost = Block.emptyPost()
                        draftBlocks = [Block.emptyTextBlock(postId: draftPost.id)]
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Add block action here if needed
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingPostEditor) {
            ZStack {
                Color.white.ignoresSafeArea()
                PostEditorView(
                    post: draftPost,
                    blocks: draftBlocks,
                    boardBlock: boardBlock(for: draftPost.boardId),
                    onSave: { newPost, newBlocks in
                        blockStore.blocks.append(newPost)
                        blockStore.blocks.append(contentsOf: newBlocks)
                        blockStore.saveBlocks()
                    },
                    saveBlocks: {
                        blockStore.saveBlocks()
                    }
                )
            }
        }
    }

    private var postList: some View {
        ForEach(postsToDisplay(), id: \.id) { post in
            PostView(
                post: post,
                boardBlock: boardBlock(for: post.boardId),
                blocks: blocksForPost(post.id),
                onEdit: {
                    // Implement edit functionality here if needed
                },
                onDelete: {
                    blockStore.blocks.removeAll { $0.id == post.id }
                },
                focusedBlockId: $focusedBlockId,
                onDuplicate: { duplicated in
                    var newBlock = duplicated
                    newBlock.id = UUID()
                    blockStore.blocks.append(newBlock)
                },
                saveBlocks: {
                    blockStore.saveBlocks()
                }
            )
        }
    }

    private func postsToDisplay() -> [Block] {
        blockStore.blocks.filter { $0.type == .post && $0.id != Block.unassignedPostId && (board == nil || $0.boardId == board!.id) }
    }

    private func blocksForPost(_ postId: UUID) -> [Block] {
        blockStore.blocks.filter { $0.postId == postId && $0.type != .post && $0.type != .board }
    }

    private func boardBlock(for boardId: UUID?) -> Block? {
        guard let boardId = boardId else { return nil }
        return blockStore.blocks.first { $0.id == boardId && $0.type == .board }
    }
}
