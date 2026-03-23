# CLAUDE.md — CrossWave

## プロジェクト概要

CrossWave は macOS ネイティブのアマチュア無線ログ管理クライアント（SwiftUI）。
バックエンド `open-logbook`（Rust / SQLite）と REST API で通信する。

**コンセプト**: HAMLOGの閉じた世界からオープンDBへ。SQLite + 公開APIで自由なインフラを構築する。

## ビルド・実行

```bash
# Xcode で開く
open CrossWave.xcodeproj

# ビルド & 実行
# Xcode > Product > Run (⌘R)
# または
xcodebuild -project CrossWave.xcodeproj -scheme CrossWave -configuration Debug build
```

- **Deployment Target**: macOS 26.2
- **Swift**: 5.0
- **外部依存**: なし（Apple フレームワークのみ）
- **Bundle ID**: `com.kikyujin.CrossWave`

## バックエンド接続

| サービス | URL | 用途 |
|---------|-----|------|
| open-logbook（テスト） | `http://localhost:8670` | API サーバー |
| open-logbook（本番） | `http://WestWing:8670` | m4max 上で稼働 |
| bonelessham | `http://b760itx:8669` | HAMLOG ブリッジ（private） |

API ベース URL は `Services/AppConstants.swift` で定義。

## ディレクトリ構造

```
CrossWave/
├── CrossWaveApp.swift          # エントリポイント（WindowGroup + コマンド定義）
├── Assets.xcassets/            # アイコン・カラーアセット
├── Models/
│   ├── QSORecord.swift         # データモデル（QSORecord, QSOInput, etc.）
│   ├── BoardContext.swift      # ログボード起動パラメータ（フィルタ・onSelect）
│   └── StringExtensions.swift  # 全角→半角変換
├── Views/
│   ├── ControlBoardView.swift  # ルートボード（LOG BOARD / NEW QSO / CSV IMPORT）
│   ├── ContentView.swift       # ログボード（一覧表示 + ツールバー）
│   ├── QSOInputView.swift      # QSO入力ダイアログ（820x420）
│   ├── QSOListView.swift       # QSOテーブル（LazyVStack）
│   ├── QSORowView.swift        # 行レンダラー（ホバーエフェクト付き）
│   ├── StatsBarView.swift      # 統計バー（TOTAL / LATEST / BAND / LAST / QSL）
│   ├── ExportDialogView.swift  # CSVエクスポートダイアログ
│   ├── ComboField.swift        # ドロップダウン付きテキストフィールド
│   └── CWColors.swift          # カラーパレット定義
└── Services/
    ├── LogbookAPI.swift         # API クライアント（async/await）
    ├── FloatingPanelController.swift  # NSPanel ウィンドウ管理
    └── AppConstants.swift       # 定数・通知名・UserDefaultsキー
```

## アーキテクチャ

### パターン
- **MVVM-lite**: LogbookAPI（ObservableObject）を Views が監視
- **NSPanel フローティングウィンドウ**: FloatingPanelController で管理
- **通知ベースのボード間通信**: NotificationCenter 使用

### ボード親子構造
```
コントロールボード（ルート、onSelect=nil）
  ├─ ログボード(1) — ダブルクリック→何も起きない
  └─ QSOボード(A)
       └─ ログボード(2) — フィルタ付き、ダブルクリック→注入
```

### 通知
| 通知名 | 発火元 | 受信元 | 意味 |
|--------|--------|--------|------|
| `qso.updated` | QSOボード / コントロールボード | ログボード | QSOデータが追加・更新された |
| `qso.inject` | ログボード（onSelect経由） | QSOボード | 注入対象レコードidを通知 |

### 注入パターン
```
CALLSIGN入力 + Enter → フィルタ付きログボード(2)を開く
  → ダブルクリック → context.onSelect?(record.id) → idだけ渡す
    → QSOボード: GET /api/qso/{id} → NAME/QTH/CODE/REM1/REM2を注入
```
注入ルール: 注入元が空でなければ無条件上書き。空なら既存値を残す。

## 用語

| 用語 | 説明 |
|------|------|
| ボード | ウィンドウ/パネルの統一呼称 |
| ログボード | QSOリスト表示ボード |
| QSOボード | QSO入力/編集ボード |
| コントロールボード | アプリのルートボード |
| 注入 | ログボードからダブルクリックで親ボードにデータを渡す操作 |

## デザイン仕様

フライトボード風ダークUI。ターミナル美学。

| トークン | 色コード | 用途 |
|----------|----------|------|
| bg | `#0a0a0c` | 背景 |
| panel | `#111114` | パネル背景 |
| amber | `#f5a623` | コールサイン、数字強調 |
| green | `#39ff8a` | RST、成功、HAMLOGステータスOK |
| red | `#ff3b3b` | エラー、QSL未確認、HAMLOGステータスNG |
| blue | `#8ab4ff` | JEバッジ、モード表示 |

フォント: Share Tech Mono / Bebas Neue

## コーディング規約

- **アクター分離**: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`（プロジェクト全体）
- **API レスポンス**: snake_case → camelCase マッピング（CodingKeys で変換）
- **入力正規化**: 全角→半角変換を全入力フィールドに適用（`toHalfWidth()`）
- **パネル非表示**: `orderOut` ではなく必ず `close()` を使用すること
- **CSV エンコーディング**: HAMLOG 互換のため Shift_JIS（Windows レガシー対応）

## 既知の仕様

- id 欠番は SQLite AUTOINCREMENT の正常動作（削除済み id は再利用しない）
- Sandbox: `com.apple.security.files.user-selected.read-write` が必須
- App Sandbox: YES / Hardened Runtime: YES / Outgoing Network: YES

## 現在のフェーズ（2026-03-20 時点）

フェーズ4進行中。主な未実装:
- 既存QSO修正（PUT /api/qso/{id}）
- ログボード右クリック→削除（DELETE /api/qso/{id}）
- HAMLOGステータスランプ
- HAMLOG参照ボード
