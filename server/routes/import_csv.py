#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""POST /api/import/csv - HAMLOG CSVインポート"""

from flask import Blueprint, jsonify, request
from db import get_db_connection
import csv
import io
import unicodedata

import_csv_bp = Blueprint('import_csv', __name__)


def normalize(s: str) -> str:
    """全角→半角正規化 + トリム"""
    if not s:
        return ''
    return unicodedata.normalize('NFKC', s).strip()


@import_csv_bp.route('/api/import/csv', methods=['POST'])
def import_csv():
    """HAMLOG CSVインポート"""
    if 'file' not in request.files:
        return jsonify({'error': 'No file uploaded'}), 400

    file = request.files['file']
    if not file.filename:
        return jsonify({'error': 'Empty filename'}), 400

    # Shift-JIS で読み込み
    try:
        raw = file.read()
        text = raw.decode('shift_jis')
    except UnicodeDecodeError:
        try:
            text = raw.decode('cp932')
        except UnicodeDecodeError:
            return jsonify({'error': 'Cannot decode file (expected Shift-JIS/CP932)'}), 400

    reader = csv.reader(io.StringIO(text))

    conn = get_db_connection()
    cursor = conn.cursor()

    imported = 0
    skipped = 0
    errors = []

    try:
        for line_num, row in enumerate(reader, 1):
            if len(row) < 7:
                errors.append(f"line {line_num}: insufficient columns ({len(row)})")
                continue

            try:
                callsign = normalize(row[0])
                date = normalize(row[1])
                time_val = normalize(row[2])
                his_rst = normalize(row[3]) or '59'
                my_rst = normalize(row[4]) or '59'
                freq = normalize(row[5])
                mode = normalize(row[6])
                code = normalize(row[7]) if len(row) > 7 else ''
                grid_locator = normalize(row[8]) if len(row) > 8 else ''
                qsl_status = normalize(row[9]) if len(row) > 9 else 'N'
                name = normalize(row[10]) if len(row) > 10 else ''
                qth = normalize(row[11]) if len(row) > 11 else ''
                remarks1 = normalize(row[12]) if len(row) > 12 else ''
                remarks2 = normalize(row[13]) if len(row) > 13 else ''
                flag = int(normalize(row[14])) if len(row) > 14 and row[14].strip() else 0
                user = normalize(row[15]) if len(row) > 15 else ''

                if not callsign or not date or not time_val:
                    errors.append(f"line {line_num}: missing required field (callsign/date/time)")
                    continue

                # 重複チェック (callsign + date + time)
                cursor.execute(
                    'SELECT id FROM qso_log WHERE callsign = ? AND date = ? AND time = ?',
                    (callsign, date, time_val)
                )
                if cursor.fetchone():
                    skipped += 1
                    continue

                cursor.execute('''
                    INSERT INTO qso_log (
                        callsign, date, time, his_rst, my_rst, freq, mode,
                        code, grid_locator, qsl_status, name, qth,
                        remarks1, remarks2, flag, user, source
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'hamlog_csv')
                ''', (
                    callsign, date, time_val, his_rst, my_rst, freq, mode,
                    code, grid_locator, qsl_status, name, qth,
                    remarks1, remarks2, flag, user
                ))
                imported += 1

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

            except Exception as e:
                errors.append(f"line {line_num}: {str(e)}")
                continue

        conn.commit()

    except Exception as e:
        conn.rollback()
        conn.close()
        return jsonify({'error': f'Import failed: {str(e)}'}), 500

    finally:
        conn.close()

    result = {
        'status': 'success',
        'imported': imported,
        'skipped': skipped,
        'errors': len(errors),
    }
    if errors:
        result['error_details'] = errors[:20]  # 最大20件まで

    return jsonify(result), 200
