#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Open Logbook API Server (Docker-free版)
アマチュア無線 & フリーライセンス無線用ログブックシステム
"""

from flask import Flask, jsonify, request
from flask_cors import CORS
import os
import sqlite3
import requests

from db import init_db, get_db_connection
from routes.qso import qso_bp
from routes.import_csv import import_csv_bp

app = Flask(__name__)
CORS(app)

BONELESSHAM_API = os.environ.get('BONELESSHAM_API', 'http://b760itx.chihuahua-platy.ts.net:8669')

# Blueprint登録
app.register_blueprint(qso_bp)
app.register_blueprint(import_csv_bp)

# ====================
# ヘルパー関数
# ====================

# ====================
# API エンドポイント
# ====================

@app.route('/')
def index():
    """ルートアクセス時の情報"""
    return jsonify({
        'name': 'Open Logbook API',
        'version': '0.3.0',
        'status': 'running',
        'endpoints': {
            'health': '/api/health',
            'qso': '/api/qso',
            'qso_detail': '/api/qso/<id>',
            'callsign_cache': '/api/callsign_cache?q=<prefix>',
            'import_csv': '/api/import/csv',
            'export_csv': '/api/qso/export/csv',
            'callsign_search': '/api/callsign/search?q=<query>',
            'callsign_lookup': '/api/callsign/lookup?q=<callsign>',
            'hamlog_status': '/api/hamlog/status',
            'stats': '/api/stats'
        }
    })

@app.route('/api/health')
def health():
    """ヘルスチェック"""
    return jsonify({'status': 'ok'})

@app.route('/api/callsign/search')
def search_callsign():
    """コールサイン自動補完用検索"""
    query = request.args.get('q', '')
    limit = request.args.get('limit', 10, type=int)

    if not query:
        return jsonify([])

    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute('''
        SELECT DISTINCT callsign, name, qth, MAX(date) as last_qso
        FROM qso_log
        WHERE callsign LIKE ? OR callsign LIKE ?
        GROUP BY callsign
        ORDER BY last_qso DESC
        LIMIT ?
    ''', (f'{query}%', f'{query.upper()}%', limit))

    results = [{
        'callsign': row[0],
        'name': row[1] or '',
        'qth': row[2] or '',
        'last_qso': row[3]
    } for row in cursor.fetchall()]

    conn.close()

    return jsonify(results)

@app.route('/api/callsign/lookup')
def lookup_callsign():
    """BONELESSHAM API経由のコールサイン検索（キャッシュ付き）"""
    callsign = request.args.get('q', '').upper().strip()
    if not callsign:
        return jsonify({'error': 'q parameter required'}), 400

    none_result = {'source': 'none', 'callsign': callsign,
                   'name': None, 'qth': None, 'code': None}

    conn = get_db_connection()
    cursor = conn.cursor()

    # 1. callsign_cache から完全一致検索
    cursor.execute(
        'SELECT callsign, name, qth FROM callsign_cache WHERE callsign = ?',
        (callsign,)
    )
    cached = cursor.fetchone()
    if cached:
        # 最新の code も取得
        cursor.execute('''
            SELECT code FROM qso_log
            WHERE callsign = ? AND code != ''
            ORDER BY date DESC, time DESC LIMIT 1
        ''', (callsign,))
        code_row = cursor.fetchone()
        conn.close()
        return jsonify({
            'source': 'cache',
            'callsign': cached['callsign'],
            'name': cached['name'] or None,
            'qth': cached['qth'] or None,
            'code': code_row['code'] if code_row else None
        })

    # 2. キャッシュミス かつ BONELESSHAM_API 未設定 → source: "none"
    if not BONELESSHAM_API:
        conn.close()
        return jsonify(none_result)

    # 3. BONELESSHAM API に照会
    try:
        resp = requests.get(
            f'{BONELESSHAM_API}/api/callsign',
            params={'q': callsign},
            timeout=3
        )
        if resp.status_code == 200:
            data = resp.json()
            name = data.get('name', '')
            qth = data.get('qth', '')

            # データが空なら キャッシュしない
            if not name and not qth:
                conn.close()
                return jsonify(none_result)

            # callsign_cache に upsert
            cursor.execute(
                '''INSERT OR REPLACE INTO callsign_cache (callsign, name, qth, updated_at)
                   VALUES (?, ?, ?, CURRENT_TIMESTAMP)''',
                (callsign, name, qth)
            )
            conn.commit()
            conn.close()

            return jsonify({
                'source': 'hamlog',
                'callsign': callsign,
                'name': name or None,
                'qth': qth or None,
                'code': None
            })
        else:
            conn.close()
            return jsonify(none_result)
    except requests.RequestException:
        conn.close()
        return jsonify(none_result)

@app.route('/api/hamlog/status')
def hamlog_status():
    """BONELESSHAM API ヘルスチェック"""
    if not BONELESSHAM_API:
        return jsonify({"status": "unavailable", "reason": "not_configured"})
    try:
        resp = requests.get(f"{BONELESSHAM_API}/api/status", timeout=3)
        if resp.status_code == 200:
            return jsonify({"status": "ready"})
        else:
            return jsonify({"status": "unavailable", "reason": "connection_failed"})
    except requests.RequestException:
        return jsonify({"status": "unavailable", "reason": "connection_failed"})

@app.route('/api/stats')
def get_stats():
    """統計情報取得"""
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute('SELECT COUNT(*) FROM qso_log')
    total_qsos = cursor.fetchone()[0]

    cursor.execute('''
        SELECT freq, COUNT(*) as count FROM qso_log
        GROUP BY freq ORDER BY count DESC
    ''')
    bands = [{'freq': row[0], 'count': row[1]} for row in cursor.fetchall()]

    cursor.execute('''
        SELECT mode, COUNT(*) as count FROM qso_log
        GROUP BY mode ORDER BY count DESC
    ''')
    modes = [{'mode': row[0], 'count': row[1]} for row in cursor.fetchall()]

    cursor.execute('SELECT COUNT(DISTINCT callsign) FROM qso_log')
    unique_calls = cursor.fetchone()[0]

    conn.close()

    return jsonify({
        'total_qsos': total_qsos,
        'unique_callsigns': unique_calls,
        'bands': bands,
        'modes': modes
    })


# ====================
# メイン処理
# ====================

if __name__ == '__main__':
    init_db()
    app.run(host='0.0.0.0', port=8670, debug=True)
