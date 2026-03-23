#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""DB初期化・スキーマ管理"""

import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'logbook.db')


def get_db_connection():
    """DB接続取得"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


def init_db():
    """データベース初期化"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    cursor.execute("PRAGMA journal_mode=WAL")

    # メインテーブル作成
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS qso_log (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            callsign      TEXT NOT NULL,
            date          TEXT NOT NULL,
            time          TEXT NOT NULL,
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
            notes         TEXT,
            flag          INTEGER DEFAULT 0,
            user          TEXT DEFAULT '',
            source        TEXT DEFAULT 'manual',
            created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')

    # sourceカラムがなければ追加（既存DBマイグレーション）
    cursor.execute("PRAGMA table_info(qso_log)")
    columns = [row[1] for row in cursor.fetchall()]
    if 'source' not in columns:
        cursor.execute("ALTER TABLE qso_log ADD COLUMN source TEXT DEFAULT 'manual'")
        print("  migrated: added 'source' column to qso_log")

    # コールサインキャッシュテーブル作成
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS callsign_cache (
            callsign   TEXT PRIMARY KEY,
            name       TEXT,
            qth        TEXT,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')

    # インデックス作成
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_callsign ON qso_log(callsign)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_date ON qso_log(date)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_freq ON qso_log(freq)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_mode ON qso_log(mode)')
    cursor.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_dedup ON qso_log(callsign, date, time)')

    conn.commit()
    conn.close()
    print("DB initialized:", DB_PATH)
