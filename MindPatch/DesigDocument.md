# アプリ設計書

## 1. 🎯 アプリの目的と特徴
- アナログのジャーナリングからの脱却
- タイムラインと階層構造を融合した新しいノート体験
- Notionの柔軟性 × Twitterのスピード感 × 手書きメモ対応

⸻

## 2. 🧱 データ構造とモデル設計

### 2.1 Block型（唯一の基本構造）
- `id`, `type`, `content`, `parentId`, `order`, `createdAt`, `updatedAt`, `status`, `tags`, `isPinned`, `isCollapsed`, `style`, `props`

type Block = {
  id: string;
  type: "board" | "post" | "text" | "heading1" | "heading2" | "list" | "checkbox";
  content: string;
  parentId?: string;      // 構造上の親（リスト・段落など）
  postId?: string;        // 所属するPost（投稿単位のまとまり）
  boardId?: string;       // 所属するBoard（テーマ・プロジェクト単位）
  order: number;
  createdAt: string;
  updatedAt: string;
  status?: "draft" | "published" | "archived";
  tags?: string[];
  isPinned?: boolean;
  isCollapsed?: boolean;
  style?: string;
  props?: { [key: string]: any };
};

### 2.2 階層構造のルール
- `Block`は他のBlockを親に持てる
- `Post`や`Board`もBlock型の一種
- `postId`, `boardId` は上位概念を示す

✅ blockの階層・所属を明確に分離
    • parentId：構造上の親（段落内の入れ子など）
    • postId：投稿単位のまとまり（タイムライン表示などに使用）
    • boardId：ボード単位のカテゴリ（マインドマップやプロジェクト分類用）

✅ 表示用階層情報の扱い（computedDepth）

- Blockの階層は親子関係（parentId）を再帰的に辿ることでビューごとに決定される
- タイムライン／マインドマップ／ボード表示では階層の見え方が異なるため、単一の `computedDepth` をBlock型に保持するのは不適切
- よって、`depth` 情報は `BlockNode`（blockTreeのノード構造）や ViewModel 側で `blockDepthMap: [blockId: Int]` のようにビュー単位で管理する
- Block型は構造的に最小限に保ち、ビューごとの状態構造と責務を分離する

type BlockNode = {
  block: Block;
  children: BlockNode[];
  depth: Int; // このビューでの階層（UI表示用、Block本体には持たせない）
};

✅ 初期ロードでは全Blockをメモリに保持（Block[]）
✅ 階層表示や操作時にBlockTreeへ変換し、UI用に使う
✅ 保存はJSONファイルベース（将来的にCloudKitなどに対応可能なよう構造は保持）

### 2.3 プロパティ（props）とスキーマ（propsSchema）
- カスタム属性（タグ、日付など）を持たせるための型付き辞書
- propsSchema により UI の制御と整合性維持を可能に

✅ props の型設計（型付きプロパティ）

- props は柔軟な属性拡張のために導入するが、後からの型管理は破綻しやすいため初期設計で対応しておく
- `propsSchema: { [key: string]: "string" | "date" | "boolean" | "number" | "select" | "multi-select" }` のようなスキーマ定義を別に持ち、UIの型チェックや入力制御に利用する
- 型未定義のpropsは基本的に保存・表示しないようにViewModel側で制御する
- `props` の型が `any` にならないよう、保存時にスキーマに沿って型変換・検証を行うこと

• props：カスタム属性（Notion風プロパティカラムの将来拡張に備える）

---

## 3. 🖼 表示と操作のUI設計

### 3.1 ビュー構成と基本レイアウト
- サイドバー（Board切替）
- タイムライン（Post一覧）
- ボードビュー（Markdown, Mindmap, Table）

ビュー    表示内容    ソート基準
タイムライン    board → post → block（親子順）    post: createdAt, block: order
マインドマップ    post 間の parentId によるツリー構造    order 無視して構造表示
Markdown    post配下のblockをネスト表示    block: order
Board一覧    block.type === “board”    任意（order or 最近更新順）

### 3.2 タイムラインビューのUI仕様
- 起動時はタイムライン表示
- 新規Postボタンは右下に常設（Twitterのように画面右下に「新規ポスト作成」ボタンを常時表示）
- 各Postには3点リーダーのメニュー（各ポストの左上には常時3点リーダー（Twitter風）を表示し、タップでポスト操作メニューを開く）
- 各Blockにはフォーカス時のみ操作ボタン表示（ボタンはフォーカスされているブロックのみ表示し、それ以外では非表示）
- 操作ボタンは左側に配置し、階層インデントに応じて右にずらす（block level × 16pt）
- 非表示時も透明領域を確保し、行の高さ・揃えを安定させる

### 3.3 ボードビューと拡張UI
- 左右分割ビュー（タイムライン + ボード）対応（iPad横向きでは、左にタイムライン、右にBoardビューを常時表示（DnDしやすい））
- タイムラインからブロックをDnDでボードに追加し、親子関係を直感的に構築可能にする
- Blockのインデント構造をマージンではなく位置ずれで表現
- ボードビューは3種類（Markdown / Mindmap / Table）を切り替え可能
- SidebarでBoardを切り替え、Post編集画面はモーダル or フルスクリーン（SwiftUI.sheet）
- 縦向き時はモーダル遷移とし、画面サイズに応じて柔軟に対応

---

## 4. ✍️ 入力モードと編集操作

### 4.1 手書きとテキスト入力
- Post単位でモード切替（手書き or テキスト）
- 手書き分類は自動ではなくユーザー選択
- PencilKit を活用し、手書きによる入力・編集を可能にする
- 手書き文字から構造（見出し・リストなど）を認識し、自動で block.type に反映は行わず、ユーザーが明示的に type を選択

### 4.2 Block作成とDnD操作
- Post外へのDnD移動可能（他Post・他Board含む）
- DnD仕様：
  - 通常時は全Block編集可能
  - 操作ボタンを押すと：
    - メニュー表示
    - 該当Blockの背景色が青くなる（該当ブロックの背景色が一時的に薄い青色になる）
    - 該当Blockが編集不可になる（テキスト入力不可）
    - 該当Blockが長押しでドラッグ可能になる（DnD有効化）
  - 他をタップすると元に戻る
    - メニューを非表示にする
    - 該当ブロックの背景色を元に戻す
    - 該当ブロックの編集を再度可能にする
    - DnDを無効化する（通常状態に戻る）
  - DnD中は全てのBlockが編集不可に（ドラッグ中保護のため）
  - .onDrag 開始時に親ブロックID・子孫も含めたブロックID群を渡す
  - .onDrop で新しい parentId と order を計算してすべて更新
  - order は float 型（例: 10, 20, 30）で管理し、DnD時に中央値で挿入
  - 子ブロックも再帰的にorder再計算（blockTree構造を使う）
  - 移動対象ブロックの子孫ブロックもまとめて移動（ポスト・ボードをまたいだ移動も可能）
  - DnD により postId や boardId が変更される場合、対象ブロックおよび子孫の postId / boardId も再帰的に更新

---

## 5. 📁 ファイル構成案
- `/Models`：Block, Board, Postモデル定義
- `/Views/Timeline`：タイムライン表示（TimelineView.swift, PostCardView.swift, TimelineToolbar.swift）
- `/Views/Board`：マークダウン・マインドマップ・テーブル（BoardView.swift, MarkdownBoardView.swift, MindmapBoardView.swift, TableBoardView.swift）
- `/Views/Blocks`：ブロック別ビュー（BlockView.swift, TextBlockView.swift, ListBlockView.swift, CheckboxBlockView.swift, HeadingBlockView.swift）
- `/Views/Editor`：編集画面（PostEditorView.swift, BlockEditorView.swift）
- `/Views/Sidebar`：サイドバー（SidebarView.swift, BoardSelectorView.swift）
- `/ViewModels`：状態管理とロジック（BlockStore.swift, BoardStore.swift, UIState.swift）
- `/Services`：ファイルI/Oやアウトライン記法パーサなど非UIロジック（BlockIOService.swift, OrderCalculator.swift, OutlineParser.swift）
- `/Extensions`：Swift標準型の拡張（Date+Formatted.swift, View+If.swift）
- `/Utilities`：DnD操作、ID生成など補助的な関数（DnDManager.swift, UUIDGenerator.swift）
- `/Resources`：アセットやサンプルデータ（sampleBlockData.json, Assets.xcassets）
- `/Components`：共通UIパーツ（操作ボタンなど）

### 推奨フォルダ構成例

```
JournalMemoApp/
├── 📁 Models/
│   ├── ✅ Block.swift
│   ├── BlockNode.swift
│   ├── Board.swift
│   └── PropsSchema.swift
│
├── 📁 ViewModels/
│   ├── ✅ BlockStore.swift
│   ├── BoardStore.swift
│   └── UIState.swift
│
├── 📁 Views/
│   ├── 📁 Timeline/
│   │   ├── ✅ TimelineView.swift
│   │   ├── PostCardView.swift
│   │   └── TimelineToolbar.swift
│   │
│   ├── 📁 Board/
│   │   ├── BoardView.swift
│   │   ├── MarkdownBoardView.swift
│   │   ├── MindmapBoardView.swift
│   │   └── TableBoardView.swift
│   │
│   ├── 📁 Blocks/
│   │   ├── ✅ BlockView.swift
│   │   ├── ✅ TextBlockView.swift
│   │   ├── ListBlockView.swift
│   │   ├── CheckboxBlockView.swift
│   │   └── HeadingBlockView.swift
│   │
│   ├── 📁 Editor/
│   │   ├── PostEditorView.swift
│   │   └── BlockEditorView.swift
│   │
│   ├── 📁 Sidebar/
│   │   ├── SidebarView.swift
│   │   └── BoardSelectorView.swift
│   │
│   ├── ✅ ContentView.swift
│   └── SplitView.swift
│
├── 📁 Repositories/
│   └── BlockRepository.swift
│
├── 📁 Services/
│   ├── BlockIOService.swift
│   ├── OrderCalculator.swift
│   └── OutlineParser.swift
│
├── 📁 Resources/
│   ├── sampleBlockData.json
│   └── Assets.xcassets
│
├── 📁 Extensions/
│   ├── Date+Formatted.swift
│   └── View+If.swift
│
├── 📁 Utilities/
│   ├── DnDManager.swift
│   └── UUIDGenerator.swift
│
├── JournalMemoAppApp.swift
└── Info.plist
```

---

## 6. 🌱 将来的な拡張も視野に

### 6.1 Post in Post 構造
- Post も Block の一種としてネスト可能に
- タイムライン/ツリー表示を正しく制御するために early support

```
// タイトル表示ロジック例
function getPostTitle(postBlock: Block, childBlocks: Block[]): string {
  const heading = childBlocks.find(b => b.type.startsWith("heading"));
  return heading?.content || postBlock.content || "Untitled";
}
```

- post.content の扱い
  - post.type の Block も content を持つ
  - content が空の場合、作成日時を自動で "YYYY年M月D日 H:mm" 形式で代入
  - これはタイムラインやマインドマップでのタイトル表示にも利用される
  - heading ブロックが存在する場合はそれを優先してタイトル表示してもよい

### 6.2 属性カラムビュー（Property Table）
- テーブル表示で各Blockの属性を編集・ソート
- props の設計を早期導入することで拡張を容易に

### 6.3 アウトライン記法（将来的導入）
- `-`, `*`, `#`, `[ ]` 等を先頭に書くことでインデント/型推定を可能に

✅ アウトライン記法によるブロック階層制御（将来対応）

- Markdown風アウトライン記法（例: `- タスク`, `  - サブタスク`）からBlockの階層を再構築可能にする
- 主に以下の目的で活用：
    • テキストでの高速な階層入力
    • 外部エクスポート・インポート形式としての活用
- インポート時は以下のように解析：
    • インデント深さから `depth` を求め、親の `id` を `parentId` に設定
    • UUIDを生成し、Block[]形式に変換
- 逆に、Block[]からMarkdown風のアウトラインテキストへのエクスポートも可能にする
- Tabキーによるインデント変更で `parentId` の更新も将来的に対応予定
- これにより、Notion的なアウトライン記法入力・編集との親和性を高める

---

## 7. 🔄 並び順制御（DnD・階層構造対応）

✅ 問題
    • 単純な order の昇順だけでは、「親と子をまとめてDnD」や「入れ子構造の一括移動」が困難

✅ 解決策案

案1：order を float に変更し、ソート操作を高速化
    • ex: order = 10, 20, 30... → 間に入れるときは 15
    • DnD時の全体再ソート不要、子ブロックもまとめて order 更新しやすい

案2：blockTree: [BlockNode] 形式に整形した構造を状態管理に導入
    • UI側では再帰構造をベースに表示・DnDを行い、保存時に Block[] に戻す

🔁 補足：移動時に必要な処理フロー
    • DnDでtargetIdを取得
    • targetIdと同一parentIdの子要素のorderを参照し、新しいorderを決定（floatなら中央値）
    • 子孫ブロックはpostId/parentIdの再帰更新も必要

---

## 8. 🧠 状態管理（SwiftUI設計）

@State var blocks: [Block]
@State var draggedBlockId: UUID?
@State var selectedBlockId: UUID?
@State var focusedBlockId: UUID?

DnDなどの操作に応じて、
    • blocks を blockTree に変換し、UIで操作
    • DnD後に blocks に戻して order 更新

✅ ViewModelクラス例（BlockStore.swiftなど）にて以下を管理
    • Block全体（[Block]）
    • blockTree（[BlockNode]）
    • 編集対象Block、ドラッグ中のBlock、選択中のBoard/Post などの状態

✅ Undo/Redo（将来的対応）
- Block操作の履歴を保持し、Undo/Redoをサポート
- BlockHistoryStoreクラスを用意し、過去のBlock[]状態を記録（最新数ステップのみ）

✅ 外部キーボードショートカット対応
- ⌘N：新規ポスト作成、⌘B：Board切り替え、⌘Z：Undo、⌘⇧Z：Redo など

---

## 9. 🎨 デザインポリシー（UI/UX指針）

✅ 基本方針
    • 情報密度を抑え、余白のある読みやすいレイアウト
    • タイムラインでは Twitter風のポスト枠を採用しつつ、Notionのような自由度の高い編集を実現
    • PencilKit を活用した手書き操作を第一クラス市民として扱う

✅ 手書き操作の統合
    • 手書きとテキスト入力の併用をサポート（ポスト単位で切り替え可能）
    • 手書き／テキストの切り替えはポスト単位でモードを選択、Block作成・編集はそのモードに応じて行う
    • ポストの上部に「🖋 手書き / ⌨️ テキスト」の切り替えトグルを常時表示し、現在の編集モードを明示

✅ ブロック表示
    • タイムライン：ポスト単位でカード型表示（上部にBoardアイコン、中央にblock表示）
    • マインドマップ：ノード連結スタイルで block 関係を可視化
    • 編集画面：手書き／テキスト切り替えを支援し、直感的なドラッグ＆ドロップ操作を可能に
    • 各ブロックの左側に操作ボタンを表示（Notion風）
        - ボタンはフォーカスされているブロックのみ表示し、それ以外では非表示
        - ボタンをタップすると編集・削除などのメニューが表示される

### 🔘 ブロックの操作ボタン配置（Notion風）

- 各ブロック左側に操作ボタン（メニュー、ドラッグ）を表示
- 表示位置は階層インデントに応じて右にずらす（block level × 16pt）
- 操作ボタンは通常非表示とし、対象ブロックがフォーカスされたときのみ表示
- 非表示時も透明領域を確保し、行の高さ・揃えを安定させる
    • 各ポストの左上には常時3点リーダー（Twitter風）を表示し、タップでポスト操作メニューを開く

---

## 10. ✅ まとめ：再設計のメリット

観点    最適化案
並び順    float型 order + blockTree構造
DnD    子孫をまとめて扱うロジックに変更
表示構造    Markdown風/階層化/UIスムーズに切り替え
状態管理    SwiftUIのBinding構造とViewModelを分離
拡張性    Blockの型追加で新機能もシンプルに対応可

---

本設計書は、初期実装・プロトタイプ開発・今後の拡張までを見据えた全体構想を含みます

---

## 11. 🔍 補足

- **Models/**：Block型やPropsスキーマなどデータ構造に関する定義
- **ViewModels/**：状態管理・ロジック担当
- **Views/**：UIの用途別分割（Timeline / Board / Block / Editorなど）
- **Services/**：ファイルI/Oやアウトライン記法パーサなど非UIロジック
- **Extensions/**：Swift標準型の拡張
- **Utilities/**：DnD操作、ID生成など補助的な関数
- **Resources/**：アセットやサンプルデータ


### ✅ 今後の拡張に備えた候補

- `Handwriting/`：PencilKit操作の統合
- `History/`：Undo/Redoの履歴管理
- `Shortcuts/`：外部キーボードショートカット制御
- `Cloud/`：CloudKit連携処理

---

## 🧭 開発ステップ（推奨実装順）

### 🔰 ステップ 1：最小動作プロトタイプ（MVP）
目的：Block構造とUIの動作を通して全体像を掴む

- Block型の定義と永続化（`Block.swift`, JSON保存）
- タイムラインビューの構築（`TimelineView.swift`）
- Post（type = "post"）作成・削除・表示
- Block（type = "text"）の追加・編集・削除
- 階層構造（parentId）を使った入れ子表示（インデント表示）

✅ この時点で Notion風の「入れ子テキストメモ」アプリとして機能

---

### ✍️ ステップ 2：Block編集体験の強化
目的：より柔軟な構造と操作性を実現

- Blockのtype切り替え（text / heading / list / checkbox など）
- Blockの並び順（order）制御
- 各Blockに操作ボタン（3点ボタン）表示（フォーカス時のみ）
- 入れ子構造のDnD移動（blockTree構造＋order再計算）

---

### 🧱 ステップ 3：Board・Post構造の導入
目的：テーマ・トピック単位の整理機能を追加

- Boardの作成・一覧表示（SidebarView）
- PostをBoardに紐づけて表示（boardId）
- タイムラインでBoardを切り替えて表示
- PostEditor画面（モーダル）実装
- Post配下にBlockを追加（postId）

---

### 🧠 ステップ 4：マインドマップ・Markdownビュー
目的：情報の視覚化・共有性を強化

- マインドマップビュー（parentIdによるツリー表示）
- Markdownビュー（Blockのorderと階層で整形表示）
- ビュー切替トグルの導入（Boardごとにstyle: "mindmap"などで管理）

---

### 🖋 ステップ 5：手書きモード対応
目的：iPadらしい操作体験の提供

- PencilKitによるキャンバス領域の表示（Block単位 or Post単位）
- 手書き／テキスト切り替えトグルの導入（Post上部）
- 手書きデータの保存（画像 or PKDrawingのまま）

---

### ⚙️ ステップ 6：拡張機能と改善
目的：柔軟性・拡張性・操作性の向上

- props によるカスタムプロパティ入力
- DnDでBoard間移動・Post間移動
- orderのfloat化と挿入最適化
- blockTree構造の共通化・高速化
- Undo / Redo対応（BlockHistoryStore導入）
- CloudKitやファイル保存の抽象化

---

### 🪜 ステップ別まとめ

| ステップ | 到達する機能・状態 |
|---------|------------------|
| 1 | ノートが書ける / 階層表示ができる |
| 2 | 構造編集・DnDなどのNotion的体験 |
| 3 | テーマ単位に整理 / ポスト編集画面 |
| 4 | 情報の可視化・印刷や共有可能に |
| 5 | 手書き記録にも対応し、手帳化 |
| 6 | カスタマイズ・拡張性を実現 |
