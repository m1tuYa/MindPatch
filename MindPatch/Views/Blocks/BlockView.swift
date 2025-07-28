import SwiftUI

struct CustomTextView: UIViewRepresentable {
    @Binding var text: String
    let onEnter: () -> Void
    let onShiftEnter: () -> Void
    let onTab: () -> Void
    let onShiftTab: () -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextView

        init(_ parent: CustomTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" {
                // Simplified shift detection: assume shift+enter adds newline, enter triggers onEnter
                if textView.text.last == "\n" {
                    parent.onShiftEnter()
                } else {
                    parent.onEnter()
                }
                return false
            }
            return true
        }
    }
}

struct BlockView: View {
    @Binding var block: Block
    var index: Int? = nil
    var indentLevel: Int = 0
    @Binding var focusedBlockId: UUID?
    var onDelete: ((UUID) -> Void)? = nil
    var onDuplicate: ((Block) -> Void)? = nil

    var onEnter: ((UUID) -> Void)? = nil
    var onShiftEnter: ((UUID) -> Void)? = nil
    var onTab: ((UUID) -> Void)? = nil
    var onShiftTab: ((UUID) -> Void)? = nil

    init(block: Binding<Block>, index: Int? = nil, indentLevel: Int = 0, focusedBlockId: Binding<UUID?>, onDelete: ((UUID) -> Void)? = nil, onDuplicate: ((Block) -> Void)? = nil, onEnter: ((UUID) -> Void)? = nil, onShiftEnter: ((UUID) -> Void)? = nil, onTab: ((UUID) -> Void)? = nil, onShiftTab: ((UUID) -> Void)? = nil) {
        self._block = block
        self.index = index
        self.indentLevel = indentLevel
        self._focusedBlockId = focusedBlockId
        self.onDelete = onDelete
        self.onDuplicate = onDuplicate
        self.onEnter = onEnter
        self.onShiftEnter = onShiftEnter
        self.onTab = onTab
        self.onShiftTab = onShiftTab
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
                    CustomTextView(
                        text: $block.content,
                        onEnter: { onEnter?(block.id) },
                        onShiftEnter: { onShiftEnter?(block.id) ?? block.content.append("\n") },
                        onTab: { onTab?(block.id) },
                        onShiftTab: { onShiftTab?(block.id) }
                    )
                case .heading1:
                    CustomTextView(
                        text: $block.content,
                        onEnter: { onEnter?(block.id) },
                        onShiftEnter: { onShiftEnter?(block.id) ?? block.content.append("\n") },
                        onTab: { onTab?(block.id) },
                        onShiftTab: { onShiftTab?(block.id) }
                    )
                    .font(.title2)
                    .bold()
                case .heading2:
                    CustomTextView(
                        text: $block.content,
                        onEnter: { onEnter?(block.id) },
                        onShiftEnter: { onShiftEnter?(block.id) ?? block.content.append("\n") },
                        onTab: { onTab?(block.id) },
                        onShiftTab: { onShiftTab?(block.id) }
                    )
                    .font(.title3)
                    .bold()
                case .list:
                    HStack(alignment: .top) {
                        Text("•")
                        CustomTextView(
                            text: $block.content,
                            onEnter: { onEnter?(block.id) },
                            onShiftEnter: { onShiftEnter?(block.id) ?? block.content.append("\n") },
                            onTab: { onTab?(block.id) },
                            onShiftTab: { onShiftTab?(block.id) }
                        )
                    }
                case .numberedList:
                    HStack(alignment: .top) {
                        if let index = index {
                            Text("\(index).")
                        } else {
                            Text("1.")
                        }
                        CustomTextView(
                            text: $block.content,
                            onEnter: { onEnter?(block.id) },
                            onShiftEnter: { onShiftEnter?(block.id) ?? block.content.append("\n") },
                            onTab: { onTab?(block.id) },
                            onShiftTab: { onShiftTab?(block.id) }
                        )
                    }
                case .checkbox:
                    HStack {
                        Image(systemName: block.props?["checked"]?.value as? Bool == true ? "checkmark.square" : "square")
                        CustomTextView(
                            text: $block.content,
                            onEnter: { onEnter?(block.id) },
                            onShiftEnter: { onShiftEnter?(block.id) ?? block.content.append("\n") },
                            onTab: { onTab?(block.id) },
                            onShiftTab: { onShiftTab?(block.id) }
                        )
                    }
                default:
                    Text("Unsupported block type")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.leading, CGFloat(indentLevel) * 20)
        .onChange(of: focusedBlockId) { _, newValue in
            // No focus state handling for iOS UITextView here
        }
    }
}
