# CrossWave

macOS ネイティブのアマチュア無線ログ管理クライアント。

HAMLOGの閉じた世界から脱出し、オープンDB（SQLite）とオープンAPIで自由なログ管理インフラを構築するプロジェクト。

## スクリーンショット

（準備中）

## 特徴

- **フライトボード風ダークUI** — ターミナル美学のアンバー＆グリーン配色
- **フローティングパネル** — 複数ウィンドウを自由に配置、PIN機能付き
- **キーボードファースト** — ⌘N（新規QSO）、⌘`（ボード切替）、Tab/Enter でフィールド遷移
- **コールサイン補完** — 2文字以上で候補表示、選択で NAME/QTH/CODE 自動入力
- **HAMLOG lookup** — キャッシュミス時にbonelessham経由でHAMLOG検索
- **HAMLOGステータスランプ** — 統計バーにHAMLOG接続状態をリアルタイム表示
- **注入パターン** — 過去QSOからワンクリックでデータ転記
- **QSO編集・削除** — ログボードから右クリックまたはダブルクリックで編集、削除は確認ダイアログ付き
- **HAMLOG互換エクスポート** — Shift_JIS CSV（16列）で HAMLOG に戻せる
- **全角→半角自動変換** — 日本語入力モードでも安心

## システム構成

```
CROSSWAVE（アポロ型ミッション構成）
├── bonelessham-api   第1段ロケット（HAMLOGブリッジ）🔒 private
├── open-logbook      機械船（REST API + SQLite）
└── CrossWave.app     司令船（本リポジトリ — SwiftUIクライアント）
```

## 必要環境

- **macOS** 26.2 以降
- **Xcode** 26.2 以降
- **open-logbook** サーバーが稼働していること（デフォルト: `localhost:8670`）

## ビルド

```bash
open CrossWave.xcodeproj
# Xcode > Product > Run (⌘R)
```

外部パッケージ依存なし。Apple フレームワークのみで動作。

## API エンドポイント（open-logbook）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/api/qso` | QSO一覧（limit, offset, order, callsign） |
| GET | `/api/qso/{id}` | 単一レコード取得 |
| POST | `/api/qso` | 新規QSO登録 |
| PUT | `/api/qso/{id}` | QSO更新 |
| DELETE | `/api/qso/{id}` | QSO削除 |
| POST | `/api/import/csv` | HAMLOG CSV インポート（Shift-JIS） |
| GET | `/api/qso/export/csv` | CSV エクスポート（id_from, id_to） |
| GET | `/api/callsign_cache` | コールサイン補完（q, limit） |
| GET | `/api/hamlog/status` | HAMLOGブリッジ接続ステータス |
| GET | `/api/callsign/lookup` | bham経由コールサイン検索 |

## キーボードショートカット

| キー | 動作 |
|------|------|
| ⌘N | 新規QSOボードを開く |
| ⌘\` | ボードローテーション |
| ⌘Return | QSO保存 |
| Enter | フィールド別動作（CALLSIGN→ログボード表示、REM2→保存） |
| Tab | 次のフィールドへ移動 |
| Esc | ボードを閉じる（変更ありの場合は確認、PIN時は無視） |

## ライセンス

（未定）
