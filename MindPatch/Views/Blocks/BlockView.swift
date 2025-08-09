import SwiftUI

struct CustomTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    @Binding var moveCursorToPosition: Int?
    @Binding var preferredXForFocus: CGFloat?
    @Binding var focusEdgeIsBottom: Bool?
    let onEnter: () -> Void
    let onShiftEnter: () -> Void
    let onTab: () -> Void
    let onShiftTab: () -> Void
    let onDeleteEmpty: () -> Void
    let onSplitBlock: (_ before: String, _ after: String) -> Void
    let onMergeOrDelete: (_ isEmpty: Bool) -> Void
    let onTextChange: ((String) -> Void)?
    let onMoveToPrevBlock: ((_ preferredX: CGFloat?) -> Void)?
    let onMoveToNextBlock: ((_ preferredX: CGFloat?) -> Void)?

    final class ArrowAwareTextView: UITextView {
        var onMoveToPrevBlock: ((_ preferredX: CGFloat?) -> Void)?
        var onMoveToNextBlock: ((_ preferredX: CGFloat?) -> Void)?
        var preferredX: CGFloat?

        override var keyCommands: [UIKeyCommand]? {
            return [
                UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(moveUp)),
                UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(moveDown))
            ]
        }

        @objc private func moveUp() { move(vertical: -1) }
        @objc private func moveDown() { move(vertical: +1) }

        private func move(vertical dir: Int) {
            guard let range = selectedTextRange else { return }
            let rect = caretRect(for: range.start)
            if preferredX == nil { preferredX = rect.midX }

            let lineH = font?.lineHeight ?? 18
            let target = CGPoint(x: preferredX ?? rect.midX, y: rect.midY + CGFloat(dir) * lineH)

            if let pos = closestPosition(to: target), let r = textRange(from: pos, to: pos) {
                selectedTextRange = r
            } else {
                if dir < 0 {
                    onMoveToPrevBlock?(preferredX)
                } else {
                    onMoveToNextBlock?(preferredX)
                }
            }
        }

    }

    func makeUIView(context: Context) -> UITextView {
        let textView = ArrowAwareTextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.onMoveToPrevBlock = { x in
            context.coordinator.parent.onMoveToPrevBlock?(x)
        }
        textView.onMoveToNextBlock = { x in
            context.coordinator.parent.onMoveToNextBlock?(x)
        }
        context.coordinator.lastAssignedText = text
        textView.text = text
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // 1) Apply external text only when it truly changed from the last delegate callback.
        //    Avoid fighting UIKit while user is typing / composing (IME) or holding first responder.
        if context.coordinator.lastAssignedText != text {
            if !(uiView.isFirstResponder && uiView.markedTextRange != nil) && !context.coordinator.isApplyingProgrammaticUpdate {
                context.coordinator.isApplyingProgrammaticUpdate = true
                uiView.text = text
                context.coordinator.lastAssignedText = text
                context.coordinator.isApplyingProgrammaticUpdate = false
            }
        }

        // 2) Focus handling: only act when explicitly told (caret move).
        if isFocused {
            if let pos = moveCursorToPosition {
                DispatchQueue.main.async {
                    let safe = max(0, min(pos, uiView.text.count))
                    uiView.selectedRange = NSRange(location: safe, length: 0)
                    context.coordinator.lastAssignedText = uiView.text
                    context.coordinator.lastProgrammaticCursorPosition = safe
                    context.coordinator.lastProgrammaticCursorAt = Date()
                    if !uiView.isFirstResponder { uiView.becomeFirstResponder() }
                }
                moveCursorToPosition = nil
            }
        }
        // Handle preferredXForFocus and focusEdgeIsBottom when becoming focused
        if isFocused, (preferredXForFocus != nil || focusEdgeIsBottom != nil) {
            DispatchQueue.main.async {
                guard let tv = uiView as? ArrowAwareTextView else { return }
                let x = preferredXForFocus
                let useBottom = (focusEdgeIsBottom ?? false)
                let refPos = useBottom ? tv.endOfDocument : tv.beginningOfDocument
                let refRect = tv.caretRect(for: refPos)
                let target = CGPoint(x: x ?? refRect.midX, y: refRect.midY)
                if let pos = tv.closestPosition(to: target), let r = tv.textRange(from: pos, to: pos) {
                    tv.selectedTextRange = r
                }
                tv.preferredX = x
                preferredXForFocus = nil
                focusEdgeIsBottom = nil
            }
        }
        // NOTE: Do not force resign on !isFocused to prevent focus tug-of-war.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextView
        var justBeganEditing: Bool = false
        var isApplyingProgrammaticUpdate: Bool = false
        var lastAssignedText: String = ""
        var lastProgrammaticCursorPosition: Int? = nil
        var lastProgrammaticCursorAt: Date? = nil

        init(_ parent: CustomTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.onTextChange?(textView.text)
            lastAssignedText = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
            justBeganEditing = true
            DispatchQueue.main.async { [weak self] in
                self?.justBeganEditing = false
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            if let tv = textView as? ArrowAwareTextView, let r = textView.selectedTextRange {
                tv.preferredX = textView.caretRect(for: r.start).midX
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.text = textView.text
            // Optionally notify for update if needed
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Intercept Backspace only when the caret is at the very start and there's no selection.
            if text.isEmpty {
                // If user selected some range, allow normal deletion.
                if range.length > 0 { return true }
                // If the caret was just programmatically moved, allow the system to handle one normal backspace.
                if let pos = lastProgrammaticCursorPosition, let t = lastProgrammaticCursorAt, Date().timeIntervalSince(t) < 0.25, range.location == pos {
                    // clear the marker so only the next backspace is allowed through
                    lastProgrammaticCursorPosition = nil
                    lastProgrammaticCursorAt = nil
                    return true
                }
                // Only when caret is exactly at start -> custom merge/delete.
                if range.location == 0 {
                    let isEmptyBlock = (textView.text ?? "").isEmpty
                    parent.onMergeOrDelete(isEmptyBlock)
                    return false
                }
            }
            // Handle Enter: split the block at the caret.
            if text == "\n" {
                let cursorPosition = range.location
                let currentText = textView.text ?? ""
                if cursorPosition == currentText.count {
                    // Caret at end -> after part is empty
                    parent.onSplitBlock(currentText, "")
                } else {
                    let beforeIndex = currentText.index(currentText.startIndex, offsetBy: cursorPosition)
                    let before = String(currentText[..<beforeIndex])
                    let after = String(currentText[beforeIndex...])
                    parent.onSplitBlock(before, after)
                }
                return false
            }
            // Allow system to perform the change (normal typing/deleting/middle-of-text backspace, etc.)
            return true
        }
    }
}

struct BlockView: View {
    @EnvironmentObject var blockStore: BlockStore
    @Binding var block: Block
    var index: Int? = nil
    var indentLevel: Int = 0
    @Binding var moveCursorToPosition: Int?
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

    init(
        block: Binding<Block>,
        index: Int? = nil,
        indentLevel: Int = 0,
        moveCursorToPosition: Binding<Int?>,
        focusedBlockId: Binding<UUID?>,
        onDelete: ((UUID) -> Void)? = nil,
        onDuplicate: ((Block) -> Void)? = nil,
        onEnter: ((UUID) -> Void)? = nil,
        onShiftEnter: ((UUID) -> Void)? = nil,
        onTab: ((UUID) -> Void)? = nil,
        onShiftTab: ((UUID) -> Void)? = nil,
        onDeleteEmpty: (() -> Void)? = nil,
        onSplitBlock: ((_ before: String, _ after: String) -> Void)? = nil,
        onMergeOrDelete: ((_ isEmpty: Bool) -> Void)? = nil
    ) {
        self._block = block
        self.index = index
        self.indentLevel = indentLevel
        self._moveCursorToPosition = moveCursorToPosition
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

    @State private var preferredXForFocus: CGFloat? = nil
    @State private var focusEdgeIsBottom: Bool? = nil
    var onMoveToPrevBlock: ((_ preferredX: CGFloat?) -> Void)? = nil
    var onMoveToNextBlock: ((_ preferredX: CGFloat?) -> Void)? = nil

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
                                var updated = block
                                updated.type = .text
                                blockStore.replace(updated)
                                blockStore.saveBlocks()
                            }
                            Button("見出し1") {
                                print("🔠 Change type to heading1")
                                var updated = block
                                updated.type = .heading1
                                blockStore.replace(updated)
                                blockStore.saveBlocks()
                            }
                            Button("見出し2") {
                                print("🔡 Change type to heading2")
                                var updated = block
                                updated.type = .heading2
                                blockStore.replace(updated)
                                blockStore.saveBlocks()
                            }
                            Button("リスト") {
                                print("🔘 Change type to list")
                                var updated = block
                                updated.type = .list
                                blockStore.replace(updated)
                                blockStore.saveBlocks()
                            }
                            Button("番号付きリスト") {
                                print("🔢 Change type to numberedList")
                                var updated = block
                                updated.type = .numberedList
                                blockStore.replace(updated)
                                blockStore.saveBlocks()
                            }
                            Button("チェックボックス") {
                                print("☑️ Change type to checkbox")
                                var updated = block
                                updated.type = .checkbox
                                blockStore.replace(updated)
                                blockStore.saveBlocks()
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
                        moveCursorToPosition: $moveCursorToPosition,
                        preferredXForFocus: $preferredXForFocus,
                        focusEdgeIsBottom: $focusEdgeIsBottom,
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
                            var updated = block
                            updated.content = newText
                            blockStore.replace(updated)
                        },
                        onMoveToPrevBlock: { x in onMoveToPrevBlock?(x) },
                        onMoveToNextBlock: { x in onMoveToNextBlock?(x) }
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
                        moveCursorToPosition: $moveCursorToPosition,
                        preferredXForFocus: $preferredXForFocus,
                        focusEdgeIsBottom: $focusEdgeIsBottom,
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
                            var updated = block
                            updated.content = newText
                            blockStore.replace(updated)
                        },
                        onMoveToPrevBlock: { x in onMoveToPrevBlock?(x) },
                        onMoveToNextBlock: { x in onMoveToNextBlock?(x) }
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
                        moveCursorToPosition: $moveCursorToPosition,
                        preferredXForFocus: $preferredXForFocus,
                        focusEdgeIsBottom: $focusEdgeIsBottom,
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
                            var updated = block
                            updated.content = newText
                            blockStore.replace(updated)
                        },
                        onMoveToPrevBlock: { x in onMoveToPrevBlock?(x) },
                        onMoveToNextBlock: { x in onMoveToNextBlock?(x) }
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
                            moveCursorToPosition: $moveCursorToPosition,
                            preferredXForFocus: $preferredXForFocus,
                            focusEdgeIsBottom: $focusEdgeIsBottom,
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
                                var updated = block
                                updated.content = newText
                                blockStore.replace(updated)
                            },
                            onMoveToPrevBlock: { x in onMoveToPrevBlock?(x) },
                            onMoveToNextBlock: { x in onMoveToNextBlock?(x) }
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
                            moveCursorToPosition: $moveCursorToPosition,
                            preferredXForFocus: $preferredXForFocus,
                            focusEdgeIsBottom: $focusEdgeIsBottom,
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
                                var updated = block
                                updated.content = newText
                                blockStore.replace(updated)
                            },
                            onMoveToPrevBlock: { x in onMoveToPrevBlock?(x) },
                            onMoveToNextBlock: { x in onMoveToNextBlock?(x) }
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
                            moveCursorToPosition: $moveCursorToPosition,
                            preferredXForFocus: $preferredXForFocus,
                            focusEdgeIsBottom: $focusEdgeIsBottom,
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
                                var updated = block
                                updated.content = newText
                                blockStore.replace(updated)
                            },
                            onMoveToPrevBlock: { x in onMoveToPrevBlock?(x) },
                            onMoveToNextBlock: { x in onMoveToNextBlock?(x) }
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
        .onChange(of: focusedBlockId) { _, _ in
            // No-op: focus is reflected by UIKit callbacks; avoid mutating during updates
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
