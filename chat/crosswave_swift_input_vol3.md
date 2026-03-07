# CrossWave QSO入力ダイアログ実装指示 vol.3
**日付**: 2026-03-07  
**作成**: エルマー🦊 → ちびエルマーへ

---

## ミッション

QSO入力用フローティングダイアログを実装する。  
**今回はデザインのみ。データの保存・API連携は次フェーズ。**

---

## ダイアログの出し方

- **トリガー**: ツールバーに「+ NEW QSO」ボタンを追加
- **表示方法**: `.sheet(isPresented:)` でモーダル表示
- **サイズ**: 固定幅 820px × 高さ自動（内容に合わせる）

---

## デザイン仕様

### ベースカラー
ログボードと被った時に区別できるよう、背景色を変える：

```swift
// ダイアログ背景
Color(hex: "#1a1a2e")  // 深い青紫系（ボードの #0a0a0c と差別化）

// ダイアログボーダー（上辺だけアクセント）
border-top: 2px solid CW.amber
border: 1px solid Color(hex: "#3a3a5c")
```

### パネル構造
```
┌─────────────────────────────────────────┐  ← border-top: amber 2px
│ NEW QSO          [時刻リアルタイム表示]  [✕] │  ← ヘッダー
├─────────────────────────────────────────┤
│ [CALL] [FREQ▼] [MODE▼] [HIS] [MY] [CODE] [QSL] │  ← 1行目
│ [NAME          ] [QTH                  ] │  ← 2行目
│ [REM1                                  ] │  ← 3行目
│ [REM2                                  ] │  ← 4行目
├─────────────────────────────────────────┤
│ [SAVE QSO]  [CLEAR]       Enter→次フィールド │  ← アクション行
└─────────────────────────────────────────┘
```

---

## フィールド仕様

### CALLSIGN
- 幅: 160px
- フォント: monospaced bold 18px、アンバー色
- 自動大文字変換: `.textCase(.uppercase)`

### FREQ
- 幅: 100px
- **ComboBox風**: よく使う値をピッカーで選べるが、自由入力も可
- 実装方法: `TextField` + ドロップダウンボタンの組み合わせ、またはカスタムビュー
- プリセット値:
  ```swift
  let freqPresets = ["144", "430", "1200", "50", "28", "21", "14", "7", "3.5", "1.9"]
  ```
- デフォルト: `"430"`

### MODE
- 幅: 90px
- FREQ同様のComboBox風
- プリセット値:
  ```swift
  let modePresets = ["FM", "SSB", "CW", "AM", "FT8", "FT4", "RTTY", "SSTV"]
  ```
- デフォルト: `"FM"`

### HIS / MY (RST)
- 幅: 50px 各
- 数字のみ受け付ける（2〜3桁）
- バリデーション: 入力文字を数字のみにフィルタ
- デフォルト: `"59"`
- フォント: monospaced、green色

### JCC/JCG (CODE)
- 幅: 80px
- 半角テキスト入力（バリデーションなし）
- placeholder: `"2034"`

### QSL
- 幅: 60px
- 半角テキスト入力（バリデーションなし）
- placeholder: `"J"`
- デフォルト: `"J"`

### NAME
- 幅: flex（1行目の残り半分）
- placeholder: `"氏名"`

### QTH
- 幅: flex（1行目の残り半分）
- placeholder: `"QTH"`

### REM1 / REM2
- 幅: 全幅（padding込み）
- placeholder:
  - REM1: `"Remarks 1"`
  - REM2: `"%愛知県弥富市 %Rig#46"`（hQSLマクロのヒント）

---

## フォームフィールドのスタイル

```swift
// 全フィールド共通
background: Color(hex: "#0d0d18")   // ボードより少し明るい
border: 1px solid Color(hex: "#2a2a44")
border-focus: 1px solid CW.amber + glow
border-radius: 2px
font: monospaced 13px
padding: 7px 10px
color: CW.textPrim

// ラベル（フィールド上部）
font: 9px monospaced
tracking: 3px
color: CW.textDim
uppercase
```

---

## ヘッダー

```swift
HStack {
    Text("NEW QSO")
        .font(.system(size: 18, design: .monospaced))
        .fontWeight(.bold)
        .tracking(4)
        .foregroundColor(CW.amber)
    
    Spacer()
    
    // リアルタイム時刻（1秒更新）
    Text(currentTimeString)  // "08:34:45J"
        .font(.system(size: 12, design: .monospaced))
        .foregroundColor(CW.green)
        .tracking(2)
    
    Button("✕") { dismiss() }
        .buttonStyle(.plain)
        .foregroundColor(CW.textDim)
}
.padding(.horizontal, 20)
.padding(.vertical, 12)
.background(Color(hex: "#161628"))
.overlay(Rectangle().frame(height: 1).foregroundColor(CW.border), alignment: .bottom)
```

---

## アクション行

```swift
HStack {
    // SAVEボタン（今はアクションなし、見た目だけ）
    Button("SAVE QSO") { /* TODO */ }
        .font(.system(size: 15, design: .monospaced))
        .fontWeight(.bold)
        .tracking(3)
        .foregroundColor(.black)
        .padding(.horizontal, 24)
        .padding(.vertical, 9)
        .background(CW.amber)
        .cornerRadius(2)
    
    Button("CLEAR") { /* TODO */ }
        .font(.system(size: 11, design: .monospaced))
        .tracking(2)
        .foregroundColor(CW.textMid)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(CW.border))
    
    Spacer()
    
    Text("Enter → 次フィールド  ·  Esc → キャンセル")
        .font(.system(size: 10, design: .monospaced))
        .foregroundColor(CW.textDim)
}
.padding(.horizontal, 20)
.padding(.vertical, 12)
.background(Color(hex: "#161628"))
.overlay(Rectangle().frame(height: 1).foregroundColor(CW.border), alignment: .top)
```

---

## ファイル構成

```
Views/
  QSOInputView.swift    ← 新規作成
  ComboField.swift      ← FREQ/MODE用のComboBox風コンポーネント（新規）
```

`ContentView.swift` に `@State var showingInput = false` を追加し、  
ツールバーボタンで toggle する。

---

## 完了条件

- [ ] ツールバーに「+ NEW QSO」ボタンがある
- [ ] クリックでダイアログが開く
- [ ] ダイアログ背景がボードと異なる色（青紫系）
- [ ] 全フィールドが配置されている
- [ ] FREQ / MODE がプリセット選択 + 自由入力できる
- [ ] HIS / MY が数字のみ受け付ける
- [ ] 時刻がリアルタイム表示される
- [ ] SAVE / CLEAR ボタンがある（機能なしでOK）
- [ ] Esc でダイアログが閉じる
