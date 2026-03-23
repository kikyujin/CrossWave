# CROSSWAVE — コンセプト

## CROSSWAVEとは

アマチュア無線のQSOログ管理システムです。オープンなデータベース（SQLite）とREST APIを基盤に、自分のQSOデータを自分の手元で自由に管理できる環境を提供します。

## なぜ作ったのか

日本のアマチュア無線ログ管理は、特定のソフトウェアに依存する部分が大きく、データ形式がプロプライエタリだったり、コールサイン情報の参照が特定のアプリ経由でしか行えないといった制約があります。

CROSSWAVEは「自分のデータを自分で持つ」という考え方で、この課題に取り組みます。

- **オープンなDB** — SQLiteだから、SQLで直接触れる
- **オープンなAPI** — REST APIで何とでも繋がる
- **レガシー連携はオプション** — HAMLOGとの連携機能はあるが、なくても動く

## 設計原則

1. **オープンであること** — DBはSQLite、APIは公開、誰でもクライアントを作れる
2. **自由にアクセスできること** — SQL・CLI・GUI・ブラウザ、好きな方法で
3. **リスクに正直であること** — API悪用やDB破壊の可能性を隠さず、設計で対処する
4. **モジュラーであること** — コンポーネントは交換・切り離しが可能

## リポジトリ構成

モノレポとして構成されています。

```
crosswave/
├── README.md
├── LICENSE (MIT)
├── docs/
│   ├── concept.md          ← このファイル
│   ├── roadmap.md
│   ├── architecture.md
│   └── db_schema.md
├── server/                  ← open-logbook（Flask + SQLite APIサーバー）
│   ├── app.py
│   ├── requirements.txt
│   ├── db/
│   └── frontend/
├── app/                     ← CrossWave.app（macOS, SwiftUI）
│   └── CrossWave.xcodeproj
└── bham/                    ← bonelessham-api（HAMLOGブリッジ, Windows）
    ├── hamlog_api_server.py
    ├── hamlog_api.ahk
    └── ...
```

### コンポーネントの役割

| コンポーネント | 役割 | 必須？ |
|------------|------|--------|
| **open-logbook** (server/) | データ管理・REST API・CSVインポート/エクスポート | はい |
| **CrossWave.app** (app/) | macOSネイティブクライアント | 推奨 |
| **bham** (bham/) | HAMLOG連携（コールサイン検索） | オプション |

**bhamについて**: bhamはHAMLOGのUIオートメーションに依存しており、HAMLOGのバージョンアップで動作しなくなる可能性があります。動作確認環境: Turbo HAMLOG Ver 5.47。

## システム構成

### スタンドアロン（1台完結）

```
[CrossWave.app] ──HTTP──> [open-logbook (localhost:8670)]
                                  └── SQLite logbook.db
```

`python app.py` で起動。設定不要。

### サーバー分離運用（移動運用など）

```
[CrossWave.app（ノートPC）]
      ↓ HTTP（LAN or Tailscale）
[open-logbook (自宅サーバー:8670)]
      └── SQLite logbook.db
```

接続先URLを変えるだけ。コード変更不要。移動運用先から自宅サーバーのDBに直接ログを記録できます。

### HAMLOG連携（オプション）

```
[open-logbook] ──HTTP──> [bham (windows-host:8669)]
                                └── HAMLOG
```

bhamがネットワーク上にあるとき、open-logbook経由でHAMLOGのユーザーDB検索が利用可能。未接続時はローカルのコールサインキャッシュで動作を継続。

## やらないこと

- プロプライエタリなコールサインDBの逆解析・一括抽出・再配布
- HAMLOG利用者への置き換え強制
- HAMLOG検索で得たデータの再配布（ローカルキャッシュとしての利用に限定）

## 長期ビジョン

### Stage 1: ローカルDB蓄積（現在）
- open-logbookをローカルDBとして運用
- 自分のQSO履歴からコールサインキャッシュを蓄積

### Stage 2: ユーザー間データ共有
- 希望するユーザーからのオプトインでデータ共有サーバーを構築
- コールサイン → 氏名/QTH のマッピングをコミュニティで構築
- データの出自を `source` フィールドで追跡

### Stage 3: 完全独立
- コミュニティデータの蓄積で外部検索が不要に
- QSL確認システムの自前実装

### データ共有の原則
- **オプトイン** — データ提供は完全に任意
- **プライバシー配慮** — 共有範囲は総務省公開情報と同程度に限定
- **オープンAPI** — 他の開発者も自由にアクセス可能

## 関連ドキュメント

| ドキュメント | 内容 |
|------------|------|
| [roadmap.md](roadmap.md) | 開発フェーズ・進捗状況・APIリファレンス |
| [architecture.md](architecture.md) | アプリ設計・ボードシステム・通知仕様 |
| [db_schema.md](db_schema.md) | SQLiteスキーマ定義 |
