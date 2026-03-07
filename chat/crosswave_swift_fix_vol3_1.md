# CrossWave QSO入力ダイアログ修正指示 vol.3.1
**日付**: 2026-03-07  
**作成**: エルマー🦊 → ちびエルマーへ

---

## 修正項目

### 1. 開いた時点で DATE / TIME を現在時刻で自動入力

ダイアログを開いた瞬間の日時を DATE / TIME フィールドに固定入力する。  
時刻表示ラベルはリアルタイム更新のままでOK。

#### DATE / TIME フィールドを追加

`QSOInputView.swift` の `@State` に追加：

```swift
@State private var date: String = ""
@State private var time: String = ""
```

ダイアログが表示された時点で現在時刻をセット：

```swift
.onAppear {
    let now = Date()
    let cal = Calendar.current
    let yy = String(cal.component(.year, from: now)).suffix(2)
    let mm = String(format: "%02d", cal.component(.month, from: now))
    let dd = String(format: "%02d", cal.component(.day, from: now))
    let hh = String(format: "%02d", cal.component(.hour, from: now))
    let mi = String(format: "%02d", cal.component(.minute, from: now))
    date = "\(yy)/\(mm)/\(dd)"
    time = "\(hh):\(mi)J"
}
```

#### レイアウト上の配置

1行目に CALLSIGN の右隣に DATE / TIME を追加：

```
[CALL(160px)] [DATE(90px)] [TIME(75px)] [FREQ] [MODE] [HIS] [MY] [CODE] [QSL]
```

DATE / TIME も通常の `TextField` で編集可能にする（自動入力後に手修正できる）。

---

### 2. Enterで内容が消えるバグを修正

SwiftUIの `TextField` でEnterを押すと `onSubmit` が走りフィールドがリセットされている可能性。

各 `TextField` に `.onSubmit {}` を空で設定し、デフォルト動作を抑制。  
かつ次フィールドへのフォーカス移動を明示的に実装する：

```swift
// フォーカス管理用のenum
enum InputField: Hashable {
    case callsign, date, time, freq, mode, hisRst, myRst, code, qsl, name, qth, rem1, rem2
}

@FocusState private var focusedField: InputField?
```

各フィールドに `.focused($focusedField, equals: .callsign)` を付与し、  
`.onSubmit` で次フィールドに移動：

```swift
TextField("JS2OIA", text: $callsign)
    .focused($focusedField, equals: .callsign)
    .onSubmit { focusedField = .date }

TextField("26/03/07", text: $date)
    .focused($focusedField, equals: .date)
    .onSubmit { focusedField = .time }

// ... 以降同様
// rem2 の onSubmit は空（最後のフィールド）
```

---

### 3. IME OFF（英数字フィールド）

以下のフィールドはIMEをOFFにして半角英数のみ受け付ける：  
**CALLSIGN / DATE / TIME / FREQ / MODE / HIS / MY / CODE / QSL**

SwiftUIのmacOSでIMEを抑制する方法：

```swift
// NSTextFieldのIMEを無効化するViewModifier
struct DisableIME: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {}  // macOSではこれだけでは不十分なのでNSViewRepresentableを使う
    }
}
```

macOSでは `NSViewRepresentable` でラップするのが確実：

```swift
// IME無効TextField
struct ASCIITextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)
    var textColor: NSColor = NSColor(Color(hex: "#e8e4d8"))
    var onSubmit: (() -> Void)? = nil

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.font = font
        field.textColor = textColor
        field.backgroundColor = NSColor(Color(hex: "#0d0d18"))
        field.isBezeled = false
        field.focusRingType = .none
        field.delegate = context.coordinator
        // IME無効化
        field.allowsEditingTextAttributes = false
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        var onSubmit: (() -> Void)?

        init(text: Binding<String>, onSubmit: (() -> Void)?) {
            _text = text
            self.onSubmit = onSubmit
        }

        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSTextField {
                text = field.stringValue
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                onSubmit?()
                return true  // Enterのデフォルト動作を抑制
            }
            return false
        }
    }
}
```

**CALLSIGN には大文字変換も追加**：

```swift
// Coordinator の controlTextDidChange に追加
text = field.stringValue.uppercased()
field.stringValue = text
```

---

## 適用フィールドまとめ

| フィールド | 実装 | IME | 大文字 |
|---|---|---|---|
| CALLSIGN | ASCIITextField | OFF | ON |
| DATE | ASCIITextField | OFF | - |
| TIME | ASCIITextField | OFF | - |
| FREQ | ComboField（既存） | OFF | - |
| MODE | ComboField（既存） | OFF | ON |
| HIS / MY | ASCIITextField | OFF | - |
| CODE | ASCIITextField | OFF | - |
| QSL | ASCIITextField | OFF | ON |
| NAME | TextField（既存） | ON（日本語OK） | - |
| QTH | TextField（既存） | ON（日本語OK） | - |
| REM1 / REM2 | TextField（既存） | ON（日本語OK） | - |

---

## 完了条件

- [ ] DATE / TIME フィールドが追加されている
- [ ] ダイアログを開いた瞬間に現在日時が自動入力される
- [ ] Enter で内容が消えない
- [ ] Enter で次フィールドにフォーカスが移る
- [ ] CALLSIGN / DATE / TIME / HIS / MY / CODE / QSL で日本語IMEが起動しない
- [ ] CALLSIGN / MODE / QSL が自動大文字になる
