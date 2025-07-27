import SwiftUI

struct BlockView: View {
    @Binding var block: Block
    var index: Int? = nil
    var indentLevel: Int = 0
    @Binding var focusedBlockId: UUID?
    @FocusState private var isTextFieldFocused: Bool
    var onDelete: ((UUID) -> Void)? = nil
    var onDuplicate: ((Block) -> Void)? = nil

    init(block: Binding<Block>, index: Int? = nil, indentLevel: Int = 0, focusedBlockId: Binding<UUID?>, onDelete: ((UUID) -> Void)? = nil, onDuplicate: ((Block) -> Void)? = nil) {
        self._block = block
        self.index = index
        self.indentLevel = indentLevel
        self._focusedBlockId = focusedBlockId
        self.onDelete = onDelete
        self.onDuplicate = onDuplicate
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack {
                if focusedBlockId == block.id {
                    Menu {
                        Button("削除", role: .destructive) {
                            onDelete?(block.id)
                        }
                        Button("複製") {
                            onDuplicate?(block)
                        }
                        Menu("タイプを変更") {
                            Button("テキスト") {
                                print("✏️ Change type to text")
                                block.type = .text
                            }
                            Button("見出し1") {
                                print("🔠 Change type to heading1")
                                block.type = .heading1
                            }
                            Button("見出し2") {
                                print("🔡 Change type to heading2")
                                block.type = .heading2
                            }
                            Button("リスト") {
                                print("🔘 Change type to list")
                                block.type = .list
                            }
                            Button("番号付きリスト") {
                                print("🔢 Change type to numberedList")
                                block.type = .numberedList
                            }
                            Button("チェックボックス") {
                                print("☑️ Change type to checkbox")
                                block.type = .checkbox
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.gray)
                            .padding(.trailing, 4)
                    }
                } else {
                    Color.clear
                        .frame(width: 20)
                        .padding(.trailing, 4)
                }
            }

            VStack(alignment: .leading) {
                switch block.type {
                case .text:
                    TextField("ブロック内容", text: $block.content)
                        .focused($isTextFieldFocused)
                case .heading1:
                    TextField("ブロック内容", text: $block.content)
                        .font(.title2)
                        .bold()
                        .focused($isTextFieldFocused)
                case .heading2:
                    TextField("ブロック内容", text: $block.content)
                        .font(.title3)
                        .bold()
                        .focused($isTextFieldFocused)
                case .list:
                    HStack(alignment: .top) {
                        Text("•")
                        TextField("ブロック内容", text: $block.content)
                            .focused($isTextFieldFocused)
                    }
                case .numberedList:
                    HStack(alignment: .top) {
                        if let index = index {
                            Text("\(index).")
                        } else {
                            Text("1.")
                        }
                        TextField("ブロック内容", text: $block.content)
                            .focused($isTextFieldFocused)
                    }
                case .checkbox:
                    HStack {
                        Image(systemName: block.props?["checked"]?.value as? Bool == true ? "checkmark.square" : "square")
                        TextField("ブロック内容", text: $block.content)
                            .focused($isTextFieldFocused)
                    }
                default:
                    Text("Unsupported block type")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.leading, CGFloat(indentLevel) * 12)
        .onChange(of: isTextFieldFocused) { oldValue, newValue in
            if newValue {
                focusedBlockId = block.id
            }
        }
    }
}
