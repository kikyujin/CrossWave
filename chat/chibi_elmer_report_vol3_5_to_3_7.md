# ちびエルマー実施報告: vol.3.5 ~ vol.3.7
**日付**: 2026-03-07
**報告先**: Claudeエルマー

---

## vol.3.5: 入力パネル フローティング化

### 実施内容
`.sheet`（モーダル）から NSPanel（フローティングウィンドウ）に切り替え。

### 変更ファイル

**新規: `CrossWave/Services/FloatingPanelController.swift`**
- `FloatingPanelController` — NSPanelの生成・配置・クローズを管理
- `FloatingPanelControllerWrapper` — SwiftUI側から使う `@MainActor ObservableObject` ラッパー
- `import Combine` が必要（`SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY`のため）

**変更: `CrossWave/Views/QSOInputView.swift`**
- `@Environment(\.dismiss) private var dismiss` を削除
- `let onClose: () -> Void` をプロパティとして追加
- 全ての `dismiss()` 呼び出しを `onClose()` に置換

**変更: `CrossWave/Views/ContentView.swift`**
- `@State private var showingInput = false` → `@StateObject private var panelController = FloatingPanelControllerWrapper()`
- ツールバーボタン: `showingInput = true` → `panelController.openNew()`
- `.sheet(isPresented: $showingInput) { QSOInputView() }` を削除

---

## vol.3.6: Enter問題修正

### 問題
`TextField` でEnterを押すと入力内容が見えなくなる（TABでは正常）。

### 実施内容
全フィールドの `onSubmit` で、値を自分自身に再代入してからフォーカス移動するように修正。

```swift
// 修正前
.onSubmit { focusedField = .date }

// 修正後
.onSubmit { callsign = callsign; focusedField = .date }
```

### 対象フィールド（全13箇所）
CALLSIGN, DATE, TIME, FREQ(ComboField), MODE(ComboField), HIS, MY, CODE, QSL, NAME, QTH, REM1, REM2

### 追加変更
- REM2（最終フィールド）: `onSubmit { }` → `onSubmit { rem2 = rem2; focusedField = nil }`

---

## vol.3.7: パネル動作修正

### 実施内容

**1. 最前面固定を解除**
- `panel.level = .floating` → `.normal`
- `panel.isFloatingPanel = true` → 削除
- `.hudWindow` スタイル → 削除
- `.resizable` を追加
- `.isOpaque = true` に変更

**2. 複数パネル対応**
- `private var panel: NSPanel?` → `private(set) var panels: [NSPanel] = []`
- `open()` は毎回新しいNSPanelを生成し `panels` に追加、パネルを返す
- `close(_ panel: NSPanel)` で特定のパネルだけ閉じる
- `closeAll()` で全パネル一括クローズ
- Wrapper側: `openNew()` でパネル参照をキャプチャし、`onClose` で自分自身だけ閉じる

```swift
func openNew() {
    var panelRef: NSPanel?
    let panel = controller.open(content: QSOInputView(onClose: { [weak self] in
        if let p = panelRef {
            self?.controller.close(p)
        }
    }))
    panelRef = panel
}
```

---

## 現在のファイル構成

```
CrossWave/
  Models/
    QSORecord.swift
    StringExtensions.swift          # toHalfWidth()
  Services/
    AppConstants.swift              # baseURL
    LogbookAPI.swift                # API通信
    FloatingPanelController.swift   # NSPanel管理 ★vol.3.5で新規
  Views/
    CWColors.swift                  # カラーパレット
    ContentView.swift               # メイン画面
    StatsBarView.swift              # 統計バー
    QSOListView.swift               # ログ一覧
    QSORowView.swift                # 行コンポーネント
    ComboField.swift                # FREQ/MODE用コンボ
    QSOInputView.swift              # QSO入力ダイアログ
```

---

## ビルド状態

**BUILD SUCCEEDED** (全vol適用後に確認済み)

---

## 残課題・気づき

1. **SAVE QSOのAPI呼び出し未実装** — `QSOInputView.swift:288` に `// TODO: API呼び出し（次フェーズ）` が残っている
2. **パネルの✕ボタン（タイトルバー）で閉じた場合** — NSPanelのclose通知を監視していないため、`panels` 配列にゴーストが残る可能性がある。`NSWindowDelegate` の `windowWillClose` で掃除が必要かも
3. **複数パネルの位置** — 全て同じ座標に出るので重なる。オフセットをつけるか検討
4. **Enter問題の値再セット方式** — 暫定対応。根本的にはNSViewRepresentable(`StableTextField`)への置き換えが確実
