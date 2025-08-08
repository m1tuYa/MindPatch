import SwiftUI

// ★他の構造体名と被らないようにプレフィックス "Mini" を付けています
struct MiniBlock: Codable, Identifiable {
    let id: UUID
    let content: String
}

struct MiniSaveTestView: View {
    @State private var miniBlocks: [MiniBlock] = []

    var body: some View {
        VStack {
            List(miniBlocks) { block in
                Text(block.content)
            }

            Button("＋ 新規ミニポストを追加して保存") {
                let newBlock = MiniBlock(id: UUID(), content: "📝 MiniPost: \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))")
                miniBlocks.append(newBlock)
                miniSaveBlocks()
            }
        }
        .onAppear {
            miniBlocks = miniLoadBlocks()
        }
        .padding()
    }

    // MARK: - ファイル保存・読込（独立関数名）

    private func miniDocumentURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("mini_test_data.json")
    }

    private func miniSaveBlocks() {
        let url = miniDocumentURL()
        do {
            let data = try JSONEncoder().encode(miniBlocks)
            try data.write(to: url)
            print("✅ [Mini] Saved \(miniBlocks.count) blocks to \(url.lastPathComponent)")
        } catch {
            print("❌ [Mini] Save error: \(error)")
        }
    }

    private func miniLoadBlocks() -> [MiniBlock] {
        let url = miniDocumentURL()
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([MiniBlock].self, from: data)
            print("📂 [Mini] Loaded \(decoded.count) blocks from \(url.lastPathComponent)")
            return decoded
        } catch {
            print("⚠️ [Mini] Load error: \(error)")
            return []
        }
    }
}
