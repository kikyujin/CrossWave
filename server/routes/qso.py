#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""QSOログ API (CRUD /api/qso)"""

import csv
import io
import re
from flask import Blueprint, Response, jsonify, request
from db import get_db_connection

qso_bp = Blueprint('qso', __name__)


def validate_rst(rst):
    """RSTバリデーション (従来RST 1-3桁 + デジタルモード dBレポート対応)"""
    if not rst:
        return False
    s = str(rst)
    # 従来RST: 1-3桁数字, 各桁0-9許容 (例: 5, 59, 599, 00)
    # dBレポート: +/-符号 + 1-2桁数字 (例: +20, -14, +0)
    return bool(re.match(r'^\d{1,3}$|^[+-]\d{1,2}$', s))


@qso_bp.route('/api/qso', methods=['GET'])
def get_qso():
    """QSOログ一覧取得"""
    limit = request.args.get('limit', 100, type=int)
    offset = request.args.get('offset', 0, type=int)
    order = request.args.get('order', 'desc').lower()

    if order not in ('asc', 'desc'):
        order = 'desc'

    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute(f'''
        SELECT id, callsign, date, time, his_rst, my_rst,
               freq, mode, code, grid_locator, qsl_status,
               name, qth, remarks1, remarks2, notes, flag, user, source
        FROM qso_log
        ORDER BY date {order.upper()}, time {order.upper()}
        LIMIT ? OFFSET ?
    ''', (limit, offset))

    qso_list = [dict(row) for row in cursor.fetchall()]

    cursor.execute('SELECT COUNT(*) FROM qso_log')
    total = cursor.fetchone()[0]

    conn.close()

    return jsonify({
        'total': total,
        'qso': qso_list
    })


@qso_bp.route('/api/qso/<int:qso_id>', methods=['GET'])
def get_qso_by_id(qso_id):
    """単一QSOレコード取得"""
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute('''
        SELECT id, callsign, date, time, his_rst, my_rst,
               freq, mode, code, grid_locator, qsl_status,
               name, qth, remarks1, remarks2, notes, flag, user, source
        FROM qso_log
        WHERE id = ?
    ''', (qso_id,))

    row = cursor.fetchone()
    conn.close()

    if row is None:
        return jsonify({'error': 'Not found'}), 404

    return jsonify(dict(row))


@qso_bp.route('/api/qso', methods=['POST'])
def create_qso():
    """新規QSO登録"""
    data = request.get_json()

    if not data:
        return jsonify({'error': 'No JSON body'}), 400

    # 必須フィールド
    callsign = (data.get('callsign') or '').strip()
    if not callsign:
        return jsonify({'error': 'callsign is required'}), 400

    date = (data.get('date') or '').strip()
    time_val = (data.get('time') or '').strip()
    freq = (data.get('freq') or '').strip()
    mode = (data.get('mode') or '').strip()

    if not date or not time_val or not freq or not mode:
        return jsonify({'error': 'date, time, freq, mode are required'}), 400

    # RST バリデーション
    his_rst = data.get('his_rst', '59')
    my_rst = data.get('my_rst', '59')

    if not validate_rst(his_rst):
        return jsonify({'error': f'Invalid his_rst: {his_rst}'}), 400
    if not validate_rst(my_rst):
        return jsonify({'error': f'Invalid my_rst: {my_rst}'}), 400

    # オプションフィールド
    code = data.get('code', '')
    grid_locator = data.get('grid_locator', '')
    qsl_status = data.get('qsl_status', 'N')
    name = data.get('name', '')
    qth = data.get('qth', '')
    remarks1 = data.get('remarks1', '')
    remarks2 = data.get('remarks2', '')
    notes = data.get('notes', '')
    flag = data.get('flag', 0)
    user = data.get('user', '')
    source = data.get('source', 'manual')

    conn = get_db_connection()
    cursor = conn.cursor()

    try:
        cursor.execute('''
            INSERT INTO qso_log (
                callsign, date, time, his_rst, my_rst, freq, mode,
                code, grid_locator, qsl_status, name, qth,
                remarks1, remarks2, notes, flag, user, source
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            callsign, date, time_val, his_rst, my_rst, freq, mode,
            code, grid_locator, qsl_status, name, qth,
            remarks1, remarks2, notes, flag, user, source
        ))

        log_id = cursor.lastrowid

        # callsign_cache に upsert
        if name or qth:
            cursor.execute('''
                INSERT INTO callsign_cache (callsign, name, qth, updated_at)
                VALUES (?, ?, ?, CURRENT_TIMESTAMP)
                ON CONFLICT(callsign) DO UPDATE SET
                    name = COALESCE(NULLIF(excluded.name, ''), callsign_cache.name),
                    qth = COALESCE(NULLIF(excluded.qth, ''), callsign_cache.qth),
                    updated_at = CURRENT_TIMESTAMP
            ''', (callsign, name, qth))

        conn.commit()

        # 登録したレコードを返す
        cursor.execute('''
            SELECT id, callsign, date, time, his_rst, my_rst,
                   freq, mode, code, grid_locator, qsl_status,
                   name, qth, remarks1, remarks2, notes, flag, user, source,
                   created_at, updated_at
            FROM qso_log WHERE id = ?
        ''', (log_id,))
        record = dict(cursor.fetchone())

        conn.close()
        return jsonify(record), 201

    except Exception as e:
        conn.close()
        return jsonify({'error': str(e)}), 500


@qso_bp.route('/api/qso/<int:qso_id>', methods=['PUT'])
def update_qso(qso_id):
    """QSOレコード更新（部分更新対応）"""
    data = request.get_json()

    if not data:
        return jsonify({'error': 'No JSON body'}), 400

    # RST バリデーション
    if 'his_rst' in data and not validate_rst(data['his_rst']):
        return jsonify({'error': f'Invalid his_rst: {data["his_rst"]}'}), 400
    if 'my_rst' in data and not validate_rst(data['my_rst']):
        return jsonify({'error': f'Invalid my_rst: {data["my_rst"]}'}), 400

    allowed_fields = [
        'callsign', 'date', 'time', 'his_rst', 'my_rst', 'freq', 'mode',
        'code', 'grid_locator', 'qsl_status', 'name', 'qth',
        'remarks1', 'remarks2', 'notes', 'flag', 'user', 'source'
    ]

    fields = []
    values = []
    for field in allowed_fields:
        if field in data:
            fields.append(f'{field} = ?')
            values.append(data[field])

    if not fields:
        return jsonify({'error': 'No fields to update'}), 400

    fields.append('updated_at = CURRENT_TIMESTAMP')
    values.append(qso_id)

    conn = get_db_connection()
    cursor = conn.cursor()

    try:
        # 存在確認
        cursor.execute('SELECT id FROM qso_log WHERE id = ?', (qso_id,))
        if cursor.fetchone() is None:
            conn.close()
            return jsonify({'error': 'Not found'}), 404

        query = f"UPDATE qso_log SET {', '.join(fields)} WHERE id = ?"
        cursor.execute(query, values)

        # callsign が更新された場合は callsign_cache も upsert
        callsign = data.get('callsign')
        name = data.get('name')
        qth = data.get('qth')
        if callsign and (name or qth):
            cursor.execute('''
                INSERT INTO callsign_cache (callsign, name, qth, updated_at)
                VALUES (?, ?, ?, CURRENT_TIMESTAMP)
                ON CONFLICT(callsign) DO UPDATE SET
                    name = COALESCE(NULLIF(excluded.name, ''), callsign_cache.name),
                    qth = COALESCE(NULLIF(excluded.qth, ''), callsign_cache.qth),
                    updated_at = CURRENT_TIMESTAMP
            ''', (callsign, name or '', qth or ''))

        conn.commit()

        # 更新後のレコードを返す
        cursor.execute('''
            SELECT id, callsign, date, time, his_rst, my_rst,
                   freq, mode, code, grid_locator, qsl_status,
                   name, qth, remarks1, remarks2, notes, flag, user, source,
                   created_at, updated_at
            FROM qso_log WHERE id = ?
        ''', (qso_id,))
        record = dict(cursor.fetchone())

        conn.close()
        return jsonify(record)

    except Exception as e:
        conn.close()
        return jsonify({'error': str(e)}), 500


@qso_bp.route('/api/qso/<int:qso_id>', methods=['DELETE'])
def delete_qso(qso_id):
    """QSOレコード削除"""
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute('DELETE FROM qso_log WHERE id = ?', (qso_id,))

    if cursor.rowcount == 0:
        conn.close()
        return jsonify({'error': 'Not found'}), 404

    conn.commit()
    conn.close()

    return jsonify({'status': 'deleted', 'id': qso_id})


@qso_bp.route('/api/callsign_cache', methods=['GET'])
def get_callsign_cache():
    """callsign_cache から前方一致検索（最新codeも付与）"""
    query = request.args.get('q', '').strip()
    limit = request.args.get('limit', 10, type=int)

    if not query:
        return jsonify([])

    conn = get_db_connection()
    cursor = conn.cursor()

    # callsign_cache + qso_log の最新 code を結合
    cursor.execute('''
        SELECT c.callsign, c.name, c.qth,
               (SELECT q.code FROM qso_log q
                WHERE q.callsign = c.callsign AND q.code != ''
                ORDER BY q.date DESC, q.time DESC
                LIMIT 1) AS code
        FROM callsign_cache c
        WHERE c.callsign LIKE ?
        ORDER BY c.callsign
        LIMIT ?
    ''', (f'{query.upper()}%', limit))

    results = [{
        'callsign': row['callsign'],
        'name': row['name'] or '',
        'qth': row['qth'] or '',
        'code': row['code'] or ''
    } for row in cursor.fetchall()]

    conn.close()

    return jsonify(results)


@qso_bp.route('/api/qso/export/csv', methods=['GET'])
def export_csv():
    """QSOログをShift-JIS CSVでエクスポート（ヘッダなし）"""
    id_from = request.args.get('id_from', type=int)
    id_to = request.args.get('id_to', type=int)

    conn = get_db_connection()
    cursor = conn.cursor()

    # カラム順: import_csv.py と対応
    columns = (
        'callsign, date, time, his_rst, my_rst, '
        'freq, mode, code, grid_locator, qsl_status, '
        'name, qth, remarks1, remarks2, flag, user'
    )

    if id_from is not None and id_to is not None:
        cursor.execute(
            f'SELECT {columns} FROM qso_log WHERE id BETWEEN ? AND ? ORDER BY id',
            (id_from, id_to)
        )
    elif id_from is not None:
        cursor.execute(
            f'SELECT {columns} FROM qso_log WHERE id >= ? ORDER BY id',
            (id_from,)
        )
    elif id_to is not None:
        cursor.execute(
            f'SELECT {columns} FROM qso_log WHERE id <= ? ORDER BY id',
            (id_to,)
        )
    else:
        cursor.execute(f'SELECT {columns} FROM qso_log ORDER BY id')

    rows = cursor.fetchall()
    conn.close()

    # UTF-8で書き出してからShift-JISにエンコード
    buf = io.StringIO()
    writer = csv.writer(buf)
    for row in rows:
        writer.writerow([col if col is not None else '' for col in row])

    csv_text = buf.getvalue()

    try:
        csv_bytes = csv_text.encode('shift_jis')
    except UnicodeEncodeError:
        # Shift-JISに変換できない文字がある場合はCP932にフォールバック
        csv_bytes = csv_text.encode('cp932', errors='replace')

    return Response(
        csv_bytes,
        mimetype='text/csv; charset=Shift_JIS',
        headers={'Content-Disposition': 'attachment; filename=qso_export.csv'}
    )
