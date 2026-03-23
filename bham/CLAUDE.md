# CLAUDE.md — bonelessham-api

## プロジェクト概要

Turbo HAMLOG（Delphi製アマチュア無線ログソフト）を HTTP API 化する。
AHK の UI オートメーションで HAMLOG の LOG ダイアログを操作する。

## アーキテクチャ

```
Client → Flask (port 8669) → AHK subprocess → HAMLOG (hamlogw.exe)
```

- Flask が HTTP リクエストを受け、AHK スクリプトを subprocess で呼ぶ
- AHK が Win32 API (ControlSetText/ControlGetText) で HAMLOG を操作
- AHK は JSON を stdout に出力し、Flask がパースして返す

## 重要ファイル

- `hamlog_api_server.py` — Flask サーバー本体
- `hamlog_api.ahk` — AHK UI オートメーション（AHK v1）
- `hamlog_api_ui.html` — Web UI

## HAMLOG の癖（Delphi 製）

### ウィンドウ構成
| クラス | 役割 | 備考 |
|--------|------|------|
| `TThwin` | メインウィンドウ | 起動時はこれだけ |
| `TForm_A` | LOG ダイアログ | Enter で開く。**WinClose で閉じられない** |
| `TClockF` | 時計 | 触らないこと |
| `TApplication` | アプリフレーム | 内部用 |

### LOG ダイアログ (TForm_A)
- タイトル: `ＬＯＧ-[Ａ]`（全角）— `InStr(title, "ＬＯＧ")` で判定
- **WinClose / WM_CLOSE では閉じられない**（Delphi が無視する）
- Escape は背面に回すだけ
- フィールド: TEdit1〜TEdit14（TEdit14=コールサイン, TEdit13=日付, ...）
- `Alt+A` でフィールド全クリア
- `TButton1` = &Save ボタン（ControlClick 不安定）

### コールサイン検索の流れ
1. TEdit14 にコールサインをセット
2. Enter 送信 → HAMLOG がデータを表示
3. 各 TEdit からデータを読み取る
4. **注意**: 前回のデータが残るので、検索前に Alt+A でクリア必須

### ポータブル局
- `JS2ODK/2` のように `/` を含む
- パスパラメータだとルーティングが壊れる → クエリパラメータ `?q=` を使う

## AHK v1 の注意点

- ブレース `{` を if と同じ行に書くと構文エラーになる場合がある
- `if (条件) {` は OK だが、複雑な条件では次の行に `{` を書く方が安全
- `IfWinExist` 等のコマンド形式と `if WinExist()` の関数形式が混在可能
- `else` の前後のブレース配置に注意（コマンド形式では `else` を単独行に）

## 排他制御

- `threading.Lock` で AHK の同時実行を防止（`execute_ahk` 関数内）
- HAMLOG の UI は1つしかないため、並列操作は不可

## エンコーディング

- AHK → Python: `cp932` で読み取り
- 日本語フィールド（name, qth）は正常動作を確認済み（2026-03-23）

## API エンドポイント

| Method | Endpoint | 説明 |
|--------|----------|------|
| GET | `/api/status` | HAMLOG 起動確認 |
| GET | `/api/callsign?q={callsign}` | コールサイン検索 |
| POST | `/api/log` | ログ作成（JSON body） |
| PUT | `/api/log` | ログ更新（JSON body） |
| POST | `/api/clear` | LOG ダイアログクリア |
