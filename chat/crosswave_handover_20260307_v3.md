# CROSSWAVE ハンドオーバー
**日付**: 2026-03-07
**バージョン**: v3
**作成**: エルマー🦊

---

## プロジェクト概要

アマチュア無線ログ管理システム。HAMLOGからの脱却を目指すオープンインフラ。

```
CROSSWAVE
├── bonelessham-api   HAMLOGブリッジ（private）b760itx:8669
├── open-logbook      Flaskバックエンド + SQLite  WestWing:8670
└── CrossWave.app     SwiftUI macOSクライアント
```

---

## 用語定義

| 用語 | 説明 |
|------|------|
| ボード | ウィンドウ/パネルの統一呼称。実装形式（WindowGroup/NSPanel）を問わない |
| ログボード | QSOリスト表示ボード |
| QSOボード | QSO入力/編集ボード |
| コントロールボード | アプリのルートボード（未実装） |

---

## 現在の状態（2026-03-07 v3時点）

### フェーズ2 完了 ✅

| 機能 | 状態 |
|------|------|
| `Notification.Name.qsoUpdated` 定数定義 | ✅ |
| `POST /api/qso` 実装（open-logbook） | ✅ |
| QSOボード SAVE → POST → qso.updated 発火 | ✅ |
| ログボード qso.updated 受信 → 再取得 | ✅ |
| コールサイン補完（2文字以上でサジェスト） | ✅ |
| Enter キー処理（.onSubmit + handleEnter() 一元化） | ✅ |

### open-logbook（WestWing / m4max）

**実装済み**:
- `GET /api/qso?limit=200&offset=0&order=asc` — ログ一覧
- `POST /api/qso` — 新規QSO登録（callsign_cache upsert含む）
- `POST /api/import/csv` — HAMLOG CSV（Shift-JIS）インポート
- `GET /api/callsign_cache?q={prefix}&limit=N` — コールサイン補完

**未実装**:
- `PUT /api/qso/{id}` — QSO修正 ← フェーズ3
- `GET /api/qso/export/csv` — CSVエクスポート ← フェーズ3

### CrossWave.app（m4max / Xcode）

**実装済み**:
- QSOログ一覧（フライトボード風ダークUI）
- 統計バー（Total/最新日付/Band/最終交信/QSL未確認）
- フローティング入力ダイアログ（NSPanel）
- ⌘N で新規QSOダイアログ
- ⌘\` でボードローテーション
- 全角→半角自動変換
- DATE/TIME 自動フォーマット（YY/MM/DD、HH:MMJ/U）
- Escで閉じる（変更ありの場合確認ダイアログ）
- CALLSIGNが空の時SAVEボタン無効
- SAVE QSO → POST /api/qso → qso.updated 発火
- ログボード qso.updated 受信 → 自動再取得
- コールサイン補完（2文字以上/200msデバウンス/候補選択でNAME・QTH・CODE自動入力）
- Enterキー処理（.onSubmit + handleEnter() でフィールド別分岐）

**未実装**:
- 既存QSO修正（ダブルクリック→編集モード） ← フェーズ3
- ボードの親子関係 ← フェーズ3
- コントロールボード ← フェーズ3
- CSVエクスポート ← フェーズ3

**Enterキー動作（現状）**:

| フィールド | Enter動作 |
|-----------|----------|
| CALLSIGN | 補完候補あり→先頭確定+DATEへ / なし→DATEへ |
| DATE〜REM1 | 次フィールドへ移動（一部フィールドは止まる） |
| REM2 | canSave なら SAVE QSO 実行 |

※EnterはHAMLOG互換のおまけ。本来はTABで移動が正しい。

**既知の仕様**:
- id欠番はSQLite AUTOINCREMENTの正常動作（削除済みレコードのidは再利用しない）

---

## フェーズ3タスク

### 優先度高（HAMLOG移行に必要）

#### 1. CSVエクスポート（open-logbook）
```python
# GET /api/qso/export/csv
# HAMLOG互換フォーマットでShift-JIS出力
```

#### 2. CSVインポートUI（CrossWave.app）
- コントロールボードにCSVインポートボタン
- ファイル選択 → POST /api/import/csv

#### 3. CSVエクスポートUI（CrossWave.app）
- コントロールボードにCSVエクスポートボタン
- GET /api/qso/export/csv → ファイル保存

### 優先度中

#### 4. ボードの親子関係実装

```
コントロールボード（ルート）
  └─ ログボード(1)
        └─ QSOボード(A)
              └─ ログボード(2) ← コールサインフィルタ済み
```

- 全ボードが親ボードへの参照を持つ
- CALLSIGN + Enter → ログボード(2)をコールサインフィルタ付きで起動
- ログボード(2)の行選択 → 親QSOボード(A)にDBエントリを渡す
- QSOボード(A)は受け取ったDBエントリの日時以外をコピー

#### 5. 既存QSO修正
- ログボードの行ダブルクリック → QSOボードを編集モードで開く
- `PUT /api/qso/{id}` 実装（open-logbook）

#### 6. コントロールボード（最小実装）
- ログボードを開くボタンのみ
- CSVインポート/エクスポートボタン

### 優先度低（フェーズ4以降）
- CWボード
- 音声入力ボード
- ブラックリストボード
- ログボードのフィルタUI（コールサイン/日時/QSL）

---

## アーキテクチャ概要

→ 詳細は `crosswave_architecture_v0.9.md` 参照

**ボード種別**:
| 種別 | 説明 | 例 |
|------|------|-----|
| コントロールボード | ルート。DB管理操作担当 | CSVインポート/エクスポート |
| データボード | 確定時に親へ QSORecord を返す | ログボード、QSOボード |
| サービスボード | 確定時に親へ任意の値を返す | RIGリスト、アンテナリスト |

**通知**:
| 通知名 | 発火元 | 受信元 |
|--------|--------|--------|
| `qso.updated` | QSOボード（保存成功時）| ログボード |

---

## 環境・接続情報

| 項目 | 値 |
|------|-----|
| open-logbook URL | `http://localhost:8670`（テスト） |
| open-logbook本番 | `WestWing:8670` |
| bonelessham | `b760itx:8669` |
| DBファイル | `Open-Logbook/logbook.db` |
| Xcodeプロジェクト | `CrossWave/CrossWave.xcodeproj` |

---

## デザイン仕様

- 背景: `#0a0a0c`
- パネル: `#111114`
- アンバー: `#f5a623`（コールサイン、数字強調）
- グリーン: `#39ff8a`（RST、LIVE表示）
- ブルー: `#8ab4ff`（JEバッジ）
- フォント: Share Tech Mono / Bebas Neue
- 入力ダイアログ背景: `#1a1a2e`（ボードと差別化）

---

## 変更履歴

| バージョン | 日付 | 内容 |
|-----------|------|------|
| v1 | 2026-03-07 | 初版（エルマー作成） |
| v2 | 2026-03-07 | フェーズ2開始時点 |
| v3 | 2026-03-07 | フェーズ2完了。フェーズ3タスク定義 |
