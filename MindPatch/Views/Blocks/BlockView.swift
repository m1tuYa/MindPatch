import SwiftUI

struct CustomTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let onEnter: () -> Void
    let onShiftEnter: () -> Void
    let onTab: () -> Void
    let onShiftTab: () -> Void
    let onDeleteEmpty: () -> Void
    let onSplitBlock: (_ before: String, _ after: String) -> Void
    let onMergeOrDelete: (_ isEmpty: Bool) -> Void
    let onTextChange: ((String) -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if isFocused {
            if !uiView.isFirstResponder {
                DispatchQueue.main.async {
                    uiView.becomeFirstResponder()
                }
            }
        } else {
            if uiView.isFirstResponder {
                DispatchQueue.main.async {
                    uiView.resignFirstResponder()
                }
            }
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
            parent.onTextChange?(textView.text)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.text = textView.text
            // Optionally notify for update if needed
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text.isEmpty && range.location == 0 {
                let isEmptyBlock = textView.text.isEmpty
                // 空ブロック → 削除
                if isEmptyBlock {
                    parent.onMergeOrDelete(true)
                    return false
                }
                // 非空ブロック → 文字数が2文字以上のときだけマージ
                if range.length > 0 && textView.text.count > 1 {
                    parent.onMergeOrDelete(false)
                    return false
                }
            }
            // Enter handling
            if text == "\n" {
                let cursorPosition = range.location
                let currentText = textView.text ?? ""
                if cursorPosition == currentText.count {
                    // Cursor at end -> split with empty after
                    parent.onSplitBlock(currentText, "")
                } else {
                    let beforeIndex = currentText.index(currentText.startIndex, offsetBy: cursorPosition)
                    let before = String(currentText[..<beforeIndex])
                    let after = String(currentText[beforeIndex...])
                    parent.onSplitBlock(before, after)
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
    var onDeleteEmpty: (() -> Void)? = nil

    var onSplitBlock: ((_ before: String, _ after: String) -> Void)? = nil
    var onMergeOrDelete: ((_ isEmpty: Bool) -> Void)? = nil

    init(block: Binding<Block>, index: Int? = nil, indentLevel: Int = 0, focusedBlockId: Binding<UUID?>, onDelete: ((UUID) -> Void)? = nil, onDuplicate: ((Block) -> Void)? = nil, onEnter: ((UUID) -> Void)? = nil, onShiftEnter: ((UUID) -> Void)? = nil, onTab: ((UUID) -> Void)? = nil, onShiftTab: ((UUID) -> Void)? = nil, onDeleteEmpty: (() -> Void)? = nil, onSplitBlock: ((_ before: String, _ after: String) -> Void)? = nil, onMergeOrDelete: ((_ isEmpty: Bool) -> Void)? = nil) {
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
        self.onDeleteEmpty = onDeleteEmpty
        self.onSplitBlock = onSplitBlock
        self.onMergeOrDelete = onMergeOrDelete
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
                        isFocused: Binding(
                            get: { focusedBlockId == block.id },
                            set: { newValue in
                                if newValue {
                                    focusedBlockId = block.id
                                }
                            }
                        ),
                        onEnter: { onEnter?(block.id) ?? () },
                        onShiftEnter: { onShiftEnter?(block.id) ?? block.content.append("\n") },
                        onTab: { onTab?(block.id) },
                        onShiftTab: { onShiftTab?(block.id) },
                        onDeleteEmpty: {
                            onDeleteEmpty?()
                        },
                        onSplitBlock: { before, after in
                            onSplitBlock?(before, after)
                        },
                        onMergeOrDelete: { isEmpty in
                            onMergeOrDelete?(isEmpty)
                        },
                        onTextChange: { newText in
                            block.content = newText
                        }
                    )
                case .heading1:
                    CustomTextView(
                        text: $block.content,
                        isFocused: Binding(
                            get: { focusedBlockId == block.id },
                            set: { newValue in
                                if newValue {
                                    focusedBlockId = block.id
                                }
                            }
                        ),
                        onEnter: { onEnter?(block.id) ?? () },
                        onShiftEnter: { onShiftEnter?(block.id) ?? block.content.append("\n") },
                        onTab: { onTab?(block.id) },
                        onShiftTab: { onShiftTab?(block.id) },
                        onDeleteEmpty: {
                            onDeleteEmpty?()
                        },
                        onSplitBlock: { before, after in
                            onSplitBlock?(before, after)
                        },
                        onMergeOrDelete: { isEmpty in
                            onMergeOrDelete?(isEmpty)
                        },
                        onTextChange: { newText in
                            block.content = newText
                        }
                    )
                    .font(.title2)
                    .bold()
                case .heading2:
                    CustomTextView(
                        text: $block.content,
                        isFocused: Binding(
                            get: { focusedBlockId == block.id },
                            set: { newValue in
                                if newValue {
                                    focusedBlockId = block.id
                                }
                            }
                        ),
                        onEnter: { onEnter?(block.id) ?? () },
                        onShiftEnter: { onShiftEnter?(block.id) ?? block.content.append("\n") },
                        onTab: { onTab?(block.id) },
                        onShiftTab: { onShiftTab?(block.id) },
                        onDeleteEmpty: {
                            onDeleteEmpty?()
                        },
                        onSplitBlock: { before, after in
                            onSplitBlock?(before, after)
                        },
                        onMergeOrDelete: { isEmpty in
                            onMergeOrDelete?(isEmpty)
                        },
                        onTextChange: { newText in
                            block.content = newText
                        }
                    )
                    .font(.title3)
                    .bold()
                case .list:
                    HStack(alignment: .top) {
                        Text("•")
                        CustomTextView(
                            text: $block.content,
                            isFocused: Binding(
                                get: { focusedBlockId == block.id },
                                set: { newValue in
                                    if newValue {
                                        focusedBlockId = block.id
                                    }
                                }
                            ),
                            onEnter: { onEnter?(block.id) ?? () },
                            onShiftEnter: { onShiftEnter?(block.id) ?? block.content.append("\n") },
                            onTab: { onTab?(block.id) },
                            onShiftTab: { onShiftTab?(block.id) },
                            onDeleteEmpty: {
                                onDeleteEmpty?()
                            },
                            onSplitBlock: { before, after in
                                onSplitBlock?(before, after)
                            },
                            onMergeOrDelete: { isEmpty in
                                onMergeOrDelete?(isEmpty)
                            },
                            onTextChange: { newText in
                                block.content = newText
                            }
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
                            isFocused: Binding(
                                get: { focusedBlockId == block.id },
                                set: { newValue in
                                    if newValue {
                                        focusedBlockId = block.id
                                    }
                                }
                            ),
                            onEnter: { onEnter?(block.id) ?? () },
                            onShiftEnter: { onShiftEnter?(block.id) ?? block.content.append("\n") },
                            onTab: { onTab?(block.id) },
                            onShiftTab: { onShiftTab?(block.id) },
                            onDeleteEmpty: {
                                onDeleteEmpty?()
                            },
                            onSplitBlock: { before, after in
                                onSplitBlock?(before, after)
                            },
                            onMergeOrDelete: { isEmpty in
                                onMergeOrDelete?(isEmpty)
                            },
                            onTextChange: { newText in
                                block.content = newText
                            }
                        )
                    }
                case .checkbox:
                    HStack {
                        Image(systemName: block.props?["checked"]?.value as? Bool == true ? "checkmark.square" : "square")
                        CustomTextView(
                            text: $block.content,
                            isFocused: Binding(
                                get: { focusedBlockId == block.id },
                                set: { newValue in
                                    if newValue {
                                        focusedBlockId = block.id
                                    }
                                }
                            ),
                            onEnter: { onEnter?(block.id) ?? () },
                            onShiftEnter: { onShiftEnter?(block.id) ?? block.content.append("\n") },
                            onTab: { onTab?(block.id) },
                            onShiftTab: { onShiftTab?(block.id) },
                            onDeleteEmpty: {
                                onDeleteEmpty?()
                            },
                            onSplitBlock: { before, after in
                                onSplitBlock?(before, after)
                            },
                            onMergeOrDelete: { isEmpty in
                                onMergeOrDelete?(isEmpty)
                            },
                            onTextChange: { newText in
                                block.content = newText
                            }
                        )
                    }
                case .image:
                    if let uiImage = loadImageFromDocuments(block.content) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Text("Image not found")
                            .foregroundColor(.gray)
                    }
                default:
                    Text("Unsupported block type")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.leading, CGFloat(indentLevel) * 20)
        .onChange(of: focusedBlockId) { oldValue, newValue in
            if oldValue == block.id && newValue != block.id {
                // Focus lost -> persist changes (trigger state update)
                block.content = block.content
            }
        }
    }
}

func loadImageFromDocuments(_ filename: String) -> UIImage? {
    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let fileURL = documentsURL.appendingPathComponent(filename)
    if let data = try? Data(contentsOf: fileURL) {
        return UIImage(data: data)
    }
    return nil
}
