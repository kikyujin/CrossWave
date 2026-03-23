# CLAUDE.md — CrossWave

## プロジェクト概要

CrossWave は macOS ネイティブのアマチュア無線ログ管理クライアント（SwiftUI）。
バックエンド `open-logbook`（Flask / SQLite）と REST API で通信する。

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
| open-logbook（テスト） | `http://127.0.0.1:8670` | API サーバー（IPv6回避のため127.0.0.1指定） |
| open-logbook（本番） | `http://m4max.local:8670` | m4max 上で稼働（launchd常駐） |
| bonelessham | `http://b760itx:8669` | HAMLOG ブリッジ（private） |

API ベース URL は `Services/AppConstants.swift` で定義。

## ディレクトリ構造

```
CrossWave/
├── CrossWaveApp.swift          # エントリポイント（WindowGroup + コマンド定義）
├── Assets.xcassets/            # アイコン・カラーアセット
├── Models/
│   ├── QSORecord.swift         # データモデル（QSORecord, QSOInput, etc.）
│   ├── BoardContext.swift      # ログボード起動パラメータ（フィルタ・onSelect）+ QSOBoardMode
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
コントロールボード（ルート）
  ├─ ログボード(1) — ダブルクリック→編集モードでQSOボードを開く、右クリ→Edit/Delete
  └─ QSOボード(A)（新規 or 編集モード）
       └─ ログボード(2) — フィルタ付き、ダブルクリック→注入、右クリメニューなし
```

### 通知
| 通知名 | 発火元 | 受信元 | 意味 |
|--------|--------|--------|------|
| `qso.updated` | QSOボード / コントロールボード / ログボード（削除時） | ログボード | QSOデータが追加・更新・削除された |
| `qso.inject` | ログボード（onSelect経由） | QSOボード | 注入対象レコードidを通知 |
| `hamlog.status.updated` | LogbookAPI（staticタイマー、30秒） | ContentView | HAMLOGステータス変更を全ログボードに配信 |

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

## API クライアントメソッド（LogbookAPI）

| メソッド | 用途 |
|---------|------|
| fetchQSO(limit:offset:order:) | QSO一覧取得 |
| fetchQSO(id:) | 単一QSO取得 |
| createQSO(_:) | QSO新規作成 |
| searchCallsign(prefix:) | コールサインキャッシュ検索（入力補完） |
| importCSV(fileURL:) | HAMLOG CSVインポート |
| exportCSV(idFrom:idTo:) | CSVエクスポート |
| updateQSO(id:input:) | QSO更新（PUT /api/qso/{id}） |
| deleteQSO(id:) | QSO削除（DELETE /api/qso/{id}） |
| fetchHamlogStatus() | HAMLOG接続ステータス取得（30秒ポーリング） |
| lookupCallsign(_:) | bham経由コールサイン検索（Enter確定時） |
| startHamlogPolling() / stopHamlogPolling() | ステータスポーリング開始/停止 |

## 既知の仕様

- id 欠番は SQLite AUTOINCREMENT の正常動作（削除済み id は再利用しない）
- Sandbox: `com.apple.security.files.user-selected.read-write` が必須
- App Sandbox: YES / Hardened Runtime: YES / Outgoing Network: YES

## 現在のフェーズ（2026-03-23 時点）

フェーズ4完了。全APIクライアント実装済み。

実装済み（本日）:
- [x] HAMLOGステータスランプ（統計バー、30秒ポーリング） — 4-3
- [x] コールサイン補完にHAMLOG lookup統合（Enter確定時） — 4-4
- [x] ログボード右クリック→削除UI + 確認ダイアログ — 4-D
- [x] 既存QSO修正UI（編集モード、PUT呼び出し） — 4-E
- [x] ログボード右クリック→編集UI — 4-E
- [x] ログボードダブルクリック→編集モード（コントロールボード直下） — 4-E

その他の改善:
- baseURL を 127.0.0.1 に変更（IPv6 Connection refused 回避）
- QSOボードにCANCELボタン追加（ESCと同じ動作）
- HIS/MY RST の入力制限緩和（FT8 dBレポート +20/-14 等対応）
- ログボードNO表示のカンマ区切り除去
- QSOボードから子ログボードを開いた際、QSOボードを自動で前面に戻す
