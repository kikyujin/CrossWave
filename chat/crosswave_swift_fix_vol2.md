# CrossWave UI修正指示 vol.2
**日付**: 2026-03-07  
**作成**: エルマー🦊 → ちびエルマーへ

---

## 修正項目

### 1. 統計バーの高さを縮める

`StatsBarView.swift` の各統計セルが縦に太すぎる。  
数字と説明文だけのコンパクトなバーにする。

**目標高さ**: 約70px（現在の約1/3〜1/4）

```swift
// 各StatItemのパディングを絞る
// 数字サイズも少し小さく
// 統計ラベル(TOTAL QSOなど): 9px
// 数字: 24px程度（現在より小さく）
// サブラベル(ALL TIMEなど): 9px
```

---

### 2. NOソートをデフォルト昇順（最新が下）

`QSOListView.swift` のリスト表示順を変更。

- **現在**: id降順（最新が上）
- **変更後**: id昇順（最新が下、HAMLOGと同じ感覚）
- APIの `order=asc` に変更 or クライアント側で reverse

`LogbookAPI.swift` のURLを：
```
/api/qso?limit=200&offset=0&order=asc
```

リストは下端にスクロールした状態で初期表示：
```swift
ScrollViewReader { proxy in
    // データロード後に最後のidにscrollTo
    .onAppear {
        proxy.scrollTo(records.last?.id, anchor: .bottom)
    }
}
```

---

### 3. カラム追加・分離

#### 現在のカラム構成
```
NO / CALL / DATE / TIME / HIS / MY / FREQ / MODE / CODE / NAME+QTH
```

#### 変更後のカラム構成
```
NO / CALL / DATE / TIME / HIS / MY / FREQ / MODE / CODE / QSL / NAME / QTH / REM1 / REM2
```

#### カラム幅（変更後）
```swift
// NO       : 45px
// CALL     : 120px
// DATE     : 80px
// TIME     : 70px
// HIS      : 32px
// MY       : 32px
// FREQ     : 65px
// MODE     : 50px
// CODE     : 75px
// QSL      : 42px  ← 独立（バッジ表示）
// NAME     : 120px ← QTHと分離
// QTH      : 150px ← NAMEと分離
// REM1     : 120px ← 新規追加
// REM2     : flex  ← 新規追加（残り全部）
```

#### QSORowView.swift の修正
- `name` と `qth` を別セルに分ける
- `qslStatus` を独立したバッジセルに
- `remarks1` / `remarks2` を追加

#### QSORecord.swift の確認
`remarks1` / `remarks2` はすでにモデルに入ってるはずなのでそのまま使う。

---

## 完了条件

- [ ] 統計バーが70px程度に収まってる
- [ ] リストがid昇順（最新が一番下）
- [ ] 起動時に最下部にスクロールしてる
- [ ] QSL / NAME / QTH が別カラム
- [ ] REMARKS1 / REMARKS2 が表示される
