# CROSSWAVE

macOS ネイティブのアマチュア無線QSOログ管理システム。

オープンDB（SQLite）とオープンAPI（REST）で、自分のQSOデータを自分の手元で自由に管理できるインフラを構築するプロジェクトです。

## スクリーンショット

（準備中）

## 特徴

- **フライトボード風ダークUI** — ターミナル美学のアンバー＆グリーン配色
- **フローティングパネル** — 複数ウィンドウを自由に配置、PIN機能付き
- **キーボードファースト** — ⌘N（新規QSO）、⌘\`（ボード切替）、Tab/Enter でフィールド遷移
- **コールサイン補完** — 2文字以上で候補表示、選択で NAME/QTH/CODE 自動入力
- **HAMLOG連携（オプション）** — キャッシュミス時にHAMLOGのユーザーDB検索、接続状態をリアルタイム表示
- **注入パターン** — 過去QSOからワンクリックでデータ転記
- **QSO編集・削除** — 右クリックまたはダブルクリックで編集、削除は確認ダイアログ付き
- **HAMLOG互換エクスポート** — Shift_JIS CSV（16列）でHAMLOGに戻せる
- **全角→半角自動変換** — 日本語入力モードでも安心

## リポジトリ構成

```
crosswave/
├── app/        CrossWave.app（macOS SwiftUIクライアント）
├── server/     open-logbook（Flask + SQLite APIサーバー）
├── bham/       bonelessham-api（HAMLOGブリッジ, Windows）
└── docs/       ドキュメント
```

| コンポーネント | 説明 | 必須？ |
|------------|------|--------|
| **open-logbook** | QSOデータ管理・REST API・CSVインポート/エクスポート | はい |
| **CrossWave.app** | macOSネイティブクライアント | 推奨 |
| **bham** | HAMLOG連携（コールサイン検索） | オプション |

## セットアップ

### open-logbook（サーバー）

```bash
cd server
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python app.py
```

デフォルトで `localhost:8670` で起動します。

### CrossWave.app（クライアント）

```bash
open app/CrossWave.xcodeproj
# Xcode > Product > Run (⌘R)
```

外部パッケージ依存なし。Apple フレームワークのみで動作。

**ビルド済みバイナリ**: [Releases](../../releases) から .dmg をダウンロードできます。

### bham（HAMLOG連携・オプション）

Windows環境でHAMLOGのユーザーDB検索をネットワーク経由で利用するためのブリッジです。AutoHotkey によるUIオートメーションで動作します。

**必要なもの**: Python 3.8 以降, AutoHotkey v1.1, Turbo HAMLOG Ver 5.47

> ⚠️ **AutoHotkey v2.0 をインストールしないでください！** bham は v1.1 の文法で書かれており、v2.0 では動作しません。

セットアップ手順は `bham/` ディレクトリ内のドキュメントを参照してください。

## 必要環境

| コンポーネント | 要件 |
|------------|------|
| CrossWave.app | macOS 15 以降, Xcode 16 以降 |
| open-logbook | Python 3.10 以降 |
| bham | Windows 11, Python 3.8 以降, AutoHotkey v1.1（**v2.0は不可**）, HAMLOG Ver 5.47 |

## システム構成

### スタンドアロン（1台完結）

```
[CrossWave.app] ──HTTP──> [open-logbook (localhost:8670)]
                                  └── SQLite logbook.db
```

### サーバー分離運用（移動運用など）

```
[CrossWave.app（ノートPC）]
      ↓ HTTP（LAN or Tailscale）
[open-logbook (自宅サーバー:8670)]
      └── SQLite logbook.db
```

CrossWave.appの接続先URLを変えるだけ。移動運用先のノートPCから自宅のサーバーに直接ログを書き込めます。

## API エンドポイント

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/api/qso` | QSO一覧（limit, offset, order, callsign） |
| GET | `/api/qso/{id}` | 単一レコード取得 |
| POST | `/api/qso` | 新規QSO登録 |
| PUT | `/api/qso/{id}` | QSO更新 |
| DELETE | `/api/qso/{id}` | QSO削除 |
| POST | `/api/import/csv` | HAMLOG CSVインポート（Shift-JIS） |
| GET | `/api/qso/export/csv` | CSVエクスポート（id_from, id_to） |
| GET | `/api/callsign_cache` | コールサイン補完（q, limit） |
| GET | `/api/callsign/lookup` | コールサイン検索（HAMLOG連携時） |
| GET | `/api/hamlog/status` | HAMLOG連携ステータス |
| GET | `/api/health` | ヘルスチェック |
| GET | `/api/stats` | 統計情報 |

## キーボードショートカット

| キー | 動作 |
|------|------|
| ⌘N | 新規QSOボードを開く |
| ⌘\` | ボードローテーション |
| ⌘Return | QSO保存 |
| Enter | フィールド別動作（CALLSIGN→ログボード表示、REM2→保存） |
| Tab | 次のフィールドへ移動 |
| Esc | ボードを閉じる（変更ありの場合は確認） |

## ドキュメント

| ドキュメント | 内容 |
|------------|------|
| [docs/concept.md](docs/concept.md) | プロジェクト思想・設計原則・長期ビジョン |
| [docs/roadmap.md](docs/roadmap.md) | 開発フェーズ・進捗状況・APIリファレンス |
| [docs/architecture.md](docs/architecture.md) | アプリ設計・ボードシステム・通知仕様 |
| [docs/db_schema.md](docs/db_schema.md) | SQLiteスキーマ定義 |

## ライセンス

[MIT License](LICENSE)
