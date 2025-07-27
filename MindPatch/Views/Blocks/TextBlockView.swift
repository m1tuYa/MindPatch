

import SwiftUI

struct TextBlockView: View {
    @Binding var block: Block
    var onCommit: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading) {
            TextEditor(text: $block.content)
                .font(.body)
                .padding(4)
                .background(Color(.systemGray6))
                .cornerRadius(6)
                .onSubmit {
                    onCommit?()
                }
        }
        .padding(.vertical, 4)
    }
}
