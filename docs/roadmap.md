# CROSSWAVE — ロードマップ

## 現在地

**フェーズ4 完了** — 次はフェーズ5（運用拡張）

---

## フェーズ定義

### フェーズ1 ✅ 完了 — 基盤構築

- open-logbook Flask APIサーバー構築
- SQLite DB設計（qso_log + callsign_cache）
- QSOログ CRUD（`POST/GET/PUT/DELETE /api/qso`）
- HAMLOG CSVインポート（`POST /api/import/csv`、Shift-JIS対応、重複スキップ）
- コールサイン補完（`GET /api/callsign_cache?q=`）
- ブラウザUI（フライトボード風ダークUI）
- SQLite WALモード有効化

### フェーズ2 ✅ 完了 — SwiftUIクライアント基盤

- CrossWave.app 新規作成
- QSOログ一覧表示（ログボード）
- 統計バー（Total/最新日付/Band内訳/最終交信/QSL未確認）
- ⌘N で新規QSOボード
- 全角→半角自動変換
- DATE/TIME自動フォーマット
- コールサイン補完（2文字以上/200msデバウンス）
- SAVE QSO → POST → qso.updated通知

### フェーズ3 ✅ 完了 — エクスポート・コントロールボード

- `GET /api/qso/export/csv`（ID範囲指定）
- コントロールボード（LOG BOARD / NEW QSO / CSV IMPORT）
- ログボード EXPORTボタン + ID範囲指定ダイアログ

### フェーズ4 ✅ 完了 — UX強化・HAMLOG連携

- 現在時刻更新ボタン（NOW）
- CALLSIGN + Enter → フィルタ付きログボード表示
- EXPORTプリセット（前回終了点をUserDefaultsで記憶）
- `GET /api/qso/{id}` — 単一レコード取得
- ボード親子構造（LogBoardContext + onSelect）
- 注入パターン（ダブルクリック → id → fetch → フィールド注入）
- ボード列挙（FloatingPanelControllerWrapper）
- 親ボードクローズ時に子ボード自動クローズ
- ログボードでEnter → 新規QSOボード起動
- HAMLOGステータスランプ（30秒ポーリング、統計バー表示）
- コールサイン補完にHAMLOG lookup統合（Enter確定時）
- ログボード右クリック→削除（確認ダイアログ付き）
- QSO編集モード（PUT + ダブルクリック/右クリ→Edit）

### フェーズ5（予定）— 運用拡張

- CWボード（CW運用支援）
- 音声入力ボード
- ブラックリストボード
- ログボードのフィルタUI（コールサイン/日時/Band/QSLステータス）
- FREQ/MODEプリセットカスタム化
- ブラウザクライアント対応

### フェーズ6（長期）— オープンサーバー

- ユーザー間データ共有サーバー構築
- コールサインデータの外部ソフト非依存化
- QSL確認システムの自前実装

→ 詳細は [concept.md](concept.md) の長期ビジョンを参照

---

## HAMLOGエクスポートワークフロー（現行）

```
移動運用 → HAMLOGで記録
→ CrossWaveにCSVインポート（重複スキップ）
→ ログボードでID確認
→ EXPORT（FROM/TO指定）→ Shift-JIS CSV保存
→ HAMLOGに戻す → hQSL送信
```

---

## open-logbook API リファレンス

| メソッド | エンドポイント | 状態 |
|--------|----------|------|
| GET | `/api/qso?limit=&offset=&order=` | ✅ |
| GET | `/api/qso/{id}` | ✅ |
| POST | `/api/qso` | ✅ |
| PUT | `/api/qso/{id}` | ✅ |
| DELETE | `/api/qso/{id}` | ✅ |
| GET | `/api/callsign_cache?q=&limit=` | ✅ |
| GET | `/api/callsign/lookup?q=` | ✅ |
| POST | `/api/import/csv` | ✅ |
| GET | `/api/qso/export/csv?id_from=&id_to=` | ✅ |
| GET | `/api/export/adif` | ❌ 未実装 |
| GET | `/api/hamlog/status` | ✅ |
| GET | `/api/health` | ✅ |
| GET | `/api/stats` | ✅ |

---

## リリース条件

**フェーズ4完了済み — 公開準備中**

| 対象 | リリース形態 |
|------|-------------|
| `crosswave` モノレポ | GitHub public |
| CrossWave.app | Developer ID署名 + 公証 → .dmg を GitHub Releases |
| open-logbook (server/) | venv + `pip install` + `python app.py` で起動 |
| bham (bham/) | モノレポに同梱。HAMLOG Ver 5.47 動作確認済み |
