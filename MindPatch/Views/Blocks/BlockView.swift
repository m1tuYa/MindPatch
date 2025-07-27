import SwiftUI

struct BlockView: View {
    @Binding var block: Block
    var index: Int? = nil
    var indentLevel: Int = 0
    @Binding var focusedBlockId: UUID?

    var body: some View {
        HStack(alignment: .top) {
            ZStack {
                if block.id == focusedBlockId {
                    Button(action: {
                        // ブロックメニューボタンアクション
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.gray)
                            .padding(.trailing, 4)
                    }
                } else {
                    // Invisible placeholder to keep layout consistent
                    Color.clear
                        .frame(width: 20) // Adjust width to match button
                        .padding(.trailing, 4)
                }
            }

            VStack(alignment: .leading) {
                switch block.type {
                case .text:
                    TextField("ブロック内容", text: $block.content)
                case .heading1:
                    TextField("ブロック内容", text: $block.content)
                        .font(.title)
                        .bold()
                case .heading2:
                    TextField("ブロック内容", text: $block.content)
                        .font(.title2)
                        .bold()
                case .list:
                    HStack(alignment: .top) {
                        Text("•")
                        TextField("ブロック内容", text: $block.content)
                    }
                case .numberedList:
                    HStack(alignment: .top) {
                        if let index = index {
                            Text("\(index).")
                        } else {
                            Text("1.")
                        }
                        TextField("ブロック内容", text: $block.content)
                    }
                case .checkbox:
                    HStack {
                        Image(systemName: block.props?["checked"]?.value as? Bool == true ? "checkmark.square" : "square")
                        TextField("ブロック内容", text: $block.content)
                    }
                default:
                    Text("Unsupported block type")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.leading, CGFloat(indentLevel) * 12)
    }
}
