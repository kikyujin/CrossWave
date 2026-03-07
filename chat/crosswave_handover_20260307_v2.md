# CROSSWAVE ハンドオーバー
**日付**: 2026-03-07
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

## 現在の状態（2026-03-07時点）

### open-logbook（WestWing / m4maxでテスト中）

**実装済み**:
- `GET /api/qso?limit=200&offset=0&order=asc` — ログ一覧
- `POST /api/import/csv` — HAMLOG CSV（Shift-JIS）インポート
- callsign_cache テーブル

**未実装**:
- `POST /api/qso` — 新規QSO登録 ← **次フェーズ**
- `PUT /api/qso/{id}` — QSO修正 ← フェーズ3

**DBスキーマ**:
```sql
CREATE TABLE qso_log (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    callsign      TEXT NOT NULL,
    date          TEXT NOT NULL,       -- "26/03/07" YY/MM/DD
    time          TEXT NOT NULL,       -- "08:57J"(JST) / "00:57"(UTC)
    his_rst       TEXT DEFAULT '59',
    my_rst        TEXT DEFAULT '59',
    freq          TEXT NOT NULL,
    mode          TEXT NOT NULL,
    code          TEXT,
    grid_locator  TEXT,
    qsl_status    TEXT DEFAULT 'N',
    name          TEXT,
    qth           TEXT,
    remarks1      TEXT,
    remarks2      TEXT,
    flag          INTEGER DEFAULT 0,
    user          TEXT DEFAULT 'user',
    source        TEXT DEFAULT 'manual',  -- 'manual'/'draft'/'hamlog_csv'
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### CrossWave.app（m4max / Xcode）

**実装済み**:
- QSOログ一覧（フライトボード風ダークUI）
- 統計バー（Total/最新日付/Band/最終交信/QSL未確認）
- フローティング入力ダイアログ（NSPanel）
- ⌘N で新規QSOダイアログ
- ⌘\` でウィンドウローテーション
- 全角→半角自動変換
- DATE/TIME 自動フォーマット（YY/MM/DD、HH:MMJ/U）
- Escで閉じる（変更ありの場合確認ダイアログ）
- CALLSIGNが空の時SAVEボタン無効

**未実装**:
- SAVE QSOのAPI呼び出し ← **次フェーズ**
- コールサイン入力→過去QSOフィルタポップ ← **次フェーズ**
- 既存QSO修正 ← フェーズ3

**ファイル構成**:
```
CrossWave/CrossWave/
  CrossWaveApp.swift
  Models/
    QSORecord.swift
    StringExtensions.swift       # toHalfWidth()
  Services/
    AppConstants.swift           # baseURL = "http://localhost:8670"
    LogbookAPI.swift             # GET /api/qso
    FloatingPanelController.swift
  Views/
    CWColors.swift
    ContentView.swift
    StatsBarView.swift
    QSOListView.swift
    QSORowView.swift
    ComboField.swift             # FREQ/MODE コンボボックス
    QSOInputView.swift           # 入力ダイアログ
```

---

## 次フェーズ（フェーズ2）のタスク

### 1. open-logbook: POST /api/qso 実装

```python
# routes/qso.py に追加
@qso_bp.route('/api/qso', methods=['POST'])
def create_qso():
    data = request.get_json()
    # バリデーション: callsign必須
    # INSERT INTO qso_log ...
    # callsign_cache にもupsert
    # 登録したレコードをJSONで返す
```

**リクエストボディ**:
```json
{
  "callsign": "JF2LZT",
  "date": "26/03/07",
  "time": "09:07J",
  "his_rst": "59",
  "my_rst": "59",
  "freq": "430",
  "mode": "FM",
  "code": "2034",
  "qsl_status": "J",
  "name": "水澤/TOSHI",
  "qth": "愛知県愛西市",
  "remarks1": "",
  "remarks2": "%愛知県弥富市 %Rig#46",
  "source": "manual"
}
```

**レスポンス**:
```json
{
  "id": 36,
  "callsign": "JF2LZT",
  ...（登録したレコード全体）
}
```

### 2. CrossWave: SAVE QSOのAPI呼び出し実装

`LogbookAPI.swift` に追加：
```swift
func createQSO(_ record: QSOInput) async throws -> QSORecord
```

`QSOInputView.swift` の SAVE QSOボタン：
```swift
Button("SAVE QSO") {
    Task {
        do {
            let newRecord = try await api.createQSO(buildInput())
            // リストに追加 → 最下部にスクロール
            onSave(newRecord)
            onClose()
        } catch {
            // エラー表示
        }
    }
}
```

### 3. コールサイン入力→過去QSOフィルタポップ

コールサイン入力欄に2文字以上入力されたら、
過去QSOをフィルタしてポップアップ表示。
選択するとNAME/QTH/CODEが自動入力される。

**API**: 既存の `GET /api/qso` に `?callsign=JF2` のフィルタを追加
または callsign_cache から取得。

```swift
// QSOInputView内
@State private var callsignSuggestions: [CallsignCache] = []

// callsign onChange
if callsign.count >= 2 {
    // GET /api/callsign_cache?q={callsign} で候補取得
    // ポップアップ表示
}
```

**open-logbook側**:
```python
# GET /api/callsign_cache?q=JF2 → prefix match
```

---

## フェーズ3（次の次）

- リスト行クリック → 編集ダイアログ（QSOInputViewを再利用、初期値あり）
- `PUT /api/qso/{id}` 実装
- 元レコードとのリンク維持（`source='manual'`、idで追跡）

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

## デザイン仕様（参考）

- 背景: `#0a0a0c`
- パネル: `#111114`
- アンバー: `#f5a623`（コールサイン、数字強調）
- グリーン: `#39ff8a`（RST、LIVE表示）
- ブルー: `#8ab4ff`（JEバッジ）
- フォント: Share Tech Mono / Bebas Neue
- 入力ダイアログ背景: `#1a1a2e`（ボードと差別化）
