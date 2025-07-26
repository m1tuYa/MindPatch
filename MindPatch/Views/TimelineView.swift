

import SwiftUI

struct TimelineView: View {
    @StateObject private var store = BlockStore()

    var body: some View {
        NavigationView {
            List {
                ForEach(store.blocks.sorted(by: { $0.order < $1.order })) { block in
                    HStack(alignment: .top) {
                        Rectangle()
                            .frame(width: CGFloat((block.parentId != nil ? 1 : 0) * 16), height: 1)
                            .opacity(0) // インデント用の透明スペース
                        VStack(alignment: .leading) {
                            Text(block.content)
                                .font(.body)
                            Text("更新日: \(block.updatedAt.formatted(.dateTime.year().month().day().hour().minute()))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("タイムライン")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        store.addBlock(content: "新しいブロック")
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        TimelineView()
    }
}
