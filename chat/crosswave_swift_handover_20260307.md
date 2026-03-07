# CrossWave logbook-gui 実装指示 vol.1
**日付**: 2026-03-07  
**作成**: エルマー🦊 → ちびエルマーへ

---

## ミッション

CrossWave macOS App（SwiftUI）でQSOログ一覧を表示する。  
フライトボード風ダークUI。`open-logbook` のAPIからデータを取得する。

**今回やること（これだけ）**:
1. APIクライアント実装（`GET /api/qso`）
2. データモデル定義
3. ログ一覧ビュー実装

**やらないこと**:
- QSO入力フォーム
- WebSocket
- 設定画面
- bonelessham連携

---

## プロジェクト構成

```
CrossWave/
  CrossWave/
    App/
      CrossWaveApp.swift       ← エントリーポイント
    Models/
      QSORecord.swift          ← データモデル
    Services/
      LogbookAPI.swift         ← APIクライアント
    Views/
      ContentView.swift        ← メインビュー
      QSOListView.swift        ← ログ一覧
      QSORowView.swift         ← 1行分
      StatsBarView.swift       ← 上部統計バー
```

---

## API仕様

**ベースURL**: `http://localhost:8670`（後で変更できるよう定数化）

```
GET /api/qso?limit=200&offset=0&order=desc
```

**レスポンス**:
```json
{
  "total": 1483,
  "qso": [
    {
      "id": 35,
      "callsign": "JS2GOH",
      "date": "26/03/02",
      "time": "20:10J",
      "his_rst": "59",
      "my_rst": "59",
      "freq": "430",
      "mode": "FM",
      "code": "2034",
      "grid_locator": "",
      "qsl_status": "N",
      "name": "川尻  真治",
      "qth": "愛知県愛西市",
      "remarks1": "",
      "remarks2": "",
      "source": "hamlog_csv"
    }
  ]
}
```

---

## データモデル（QSORecord.swift）

```swift
struct QSORecord: Identifiable, Codable {
    let id: Int
    let callsign: String
    let date: String
    let time: String
    let hisRst: String
    let myRst: String
    let freq: String
    let mode: String
    let code: String
    let gridLocator: String
    let qslStatus: String
    let name: String
    let qth: String
    let remarks1: String
    let remarks2: String
    let source: String

    enum CodingKeys: String, CodingKey {
        case id, callsign, date, time, freq, mode, code, name, qth, source
        case hisRst      = "his_rst"
        case myRst       = "my_rst"
        case gridLocator = "grid_locator"
        case qslStatus   = "qsl_status"
        case remarks1, remarks2
    }
}

struct QSOResponse: Codable {
    let total: Int
    let qso: [QSORecord]
}
```

---

## デザイン仕様

### カラーパレット
```swift
// Colors.swift に定数として定義すること
static let bg         = Color(hex: "#0a0a0c")
static let panel      = Color(hex: "#111114")
static let border     = Color(hex: "#1e1e24")
static let amber      = Color(hex: "#f5a623")
static let amberDim   = Color(hex: "#7a5210")
static let green      = Color(hex: "#39ff8a")
static let textPrim   = Color(hex: "#e8e4d8")
static let textMid    = Color(hex: "#8a867a")
static let textDim    = Color(hex: "#4a4840")
static let blue       = Color(hex: "#8ab4ff")
```

### フォント
- コールサイン: `.monospacedDigit()` + bold、14px
- 日時・RST: monospaced、12px
- 統計数字: large title bold、amber色
- ラベル: 9px、letterSpacing広め、dim色

### ウィンドウ
- 最小サイズ: 1000 × 600
- 背景: `#0a0a0c`

---

## レイアウト仕様

### ウィンドウ全体
```
┌─────────────────────────────────┐
│ StatsBarView（統計5項目）        │
├─────────────────────────────────┤
│ カラムヘッダー（固定）           │
├─────────────────────────────────┤
│                                  │
│ QSOListView（スクロール）        │
│   QSORowView × n                │
│                                  │
└─────────────────────────────────┘
```

### カラム幅（固定）
```
NO      50px
CALL    130px
DATE    85px
TIME    70px
HIS     35px
MY      35px
FREQ    70px
MODE    55px
CODE    75px
NAME/QTH  flex（残り全部）
```

### QSORowView
- 高さ: 40px
- 背景: 交互に微妙に違う（ゼブラ）or ホバーでアンバー微光
- コールサイン: amber色
- QSLバッジ:
  - `J`  → green背景、緑文字
  - `JE` → blue背景、青文字
  - `N`  → dim背景、dim文字

### StatsBarView
横並び5項目：
- Total QSO（total値）
- 最新日付
- バンド（freqの最頻値）
- 最終交信時刻
- QSL未確認数（qsl_status == "N" の件数）

---

## 実装の注意点

- `@MainActor` を適切に使う
- API取得は `async/await` で
- エラー時は空リスト表示（クラッシュしない）
- ベースURLは `AppConstants.swift` に定数化：
  ```swift
  enum AppConstants {
      static let baseURL = "http://localhost:8670"
  }
  ```
- `macOS 14+` ターゲット想定でOK

---

## 完了条件

- [ ] アプリが起動する
- [ ] open-logbook が動いてれば一覧が表示される
- [ ] コールサインがアンバー色で表示される
- [ ] QSLバッジが色分けされてる
- [ ] 統計バーに総件数が出る
- [ ] open-logbook が落ちてても（空リストで）クラッシュしない
