# Open Logbook - CLAUDE.md

このファイルは Claude Code（ちびエルマー）向けのプロジェクト指示書です。

## プロジェクト概要

アマチュア無線・フリーライセンス無線用のログブックシステム。
Flask API + SQLite で動作する（venv + launchd 常駐）。

## アーキテクチャ

```
[CrossWave.app (SwiftUI)] ←→ [Flask API :8670] ←→ [SQLite logbook.db]
                                      ↕
                              [BONELESSHAM API :8669]  ← Windows機(b760itx)上のHAMLOG UIオートメーション
```

## ディレクトリ構成

```
open-logbook/
├── app.py                  # Flask API サーバー（メイン）
├── db.py                   # DB初期化・スキーマ管理
├── routes/
│   ├── __init__.py
│   ├── qso.py              # CRUD /api/qso, callsign_cache, CSV export（Blueprint）
│   └── import_csv.py       # POST /api/import/csv（Blueprint）
├── logbook.db              # SQLite本体
├── requirements.txt        # Python依存 (Flask, Flask-CORS, requests)
├── run.sh                  # 起動スクリプト（venv有効化 + app.py実行）
├── com.openlogbook.api.plist  # macOS LaunchAgent（常駐化用）
├── venv/                   # Python仮想環境
└── README.md
```

## 起動方法

```bash
./run.sh
# → http://localhost:8670/
```

### 初回セットアップ

```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## API エンドポイント一覧

| Method | Endpoint | 説明 |
|--------|----------|------|
| GET | `/` | API情報（バージョン・エンドポイント一覧） |
| GET | `/api/health` | ヘルスチェック |
| GET | `/api/qso?limit=N&offset=N&order=desc` | QSOログ一覧 |
| GET | `/api/qso/<id>` | 単一QSOレコード取得（404対応） |
| POST | `/api/qso` | 新規QSO登録（callsign_cache upsert付き） |
| PUT | `/api/qso/<id>` | QSOレコード更新（部分更新対応、callsign_cache upsert付き） |
| DELETE | `/api/qso/<id>` | QSOレコード削除（404対応） |
| GET | `/api/qso/export/csv?id_from=N&id_to=N` | Shift-JIS CSVエクスポート |
| GET | `/api/callsign_cache?q=<prefix>&limit=N` | callsign_cache前方一致検索（最新code付き） |
| POST | `/api/import/csv` | HAMLOG CSVインポート（Blueprint、multipart/form-data） |
| GET | `/api/callsign/search?q=<query>&limit=N` | コールサイン自動補完（ローカルDB前方一致） |
| GET | `/api/callsign/lookup?q=<callsign>` | コールサイン検索（cache→bham照会、エラー時はsource:"none"で空応答） |
| GET | `/api/hamlog/status` | BONELESSHAM API ヘルスチェック（ready / unavailable） |
| GET | `/api/stats` | 統計情報 |

## DB テーブル

### qso_log（メインログ）
- id, callsign, date, time, his_rst, my_rst, freq, mode, code, grid_locator, qsl_status, name, qth, remarks1, remarks2, notes, flag, user, source, created_at, updated_at
- `source`: `'manual'`（手入力）/ `'hamlog_csv'`（CSVインポート）
- ユニークインデックス: `callsign + date + time`（重複防止）

### callsign_cache（BONELESSHAM lookupキャッシュ）
- callsign (PK), name, qth, updated_at
- CSVインポート時にも name/qth を upsert

## CSVインポート仕様

- **エンコーディング**: Shift-JIS / CP932（自動フォールバック）
- **カラム順**: callsign, date, time, his_rst, my_rst, freq, mode, code, grid_locator, qsl_status, name, qth, remarks1, remarks2, flag
- **全角→半角正規化**: `unicodedata.normalize('NFKC', s)`
- **重複スキップ**: callsign + date + time が既存なら skip
- **source**: `'hamlog_csv'`

## 外部連携: BONELESSHAM API

- **環境変数**: `BONELESSHAM_API`（デフォルト: `http://b760itx.chihuahua-platy.ts.net:8669`）
- **現在のホスト**: `http://b760itx.chihuahua-platy.ts.net:8669` (b760itx.local)
- **仕組み**: Windows上のTurbo HAMLOGをAutoHotkey UIオートメーションで操作するHTTP API
- **エンドポイント**: `GET /api/callsign?q=<callsign>` でコールサイン情報を返す

## コーディング規約・注意事項

- コールサインに `/`（ポータブル表記）が含まれるため、API設計ではパスパラメータではなくクエリパラメータ (`?q=`) を使う
- RST は数字1〜3桁（従来RST）および `+/-`符号付き1〜2桁（FT8等dBレポート）を許容（`validate_rst()` でバリデーション）
- BONELESSHAM APIのホストが変わったら環境変数 `BONELESSHAM_API` を更新すること
- Blueprint パターン: 新しいルートは `routes/` 配下に Blueprint として追加する

## フロントエンド

フェーズ4時点でフロントエンド（ブラウザUI）は廃止済み。
フェーズ5でブラウザベースの新UIを構築予定。
現在のクライアントは CrossWave.app（SwiftUI）のみ。
