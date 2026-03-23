"""
HAMLOG HTTP API Server
boneless.ahkの機能をHTTP API化
"""
from flask import Flask, jsonify, request
from flask_cors import CORS
import subprocess
import json
import os
import threading

app = Flask(__name__)
CORS(app)

# AHK同時実行防止ロック
ahk_lock = threading.Lock()

# AHKスクリプトのパス(環境に応じて変更)
AHK_SCRIPT = r"C:\Users\mahito\work\bonelessham-api\hamlog_api.ahk"
AUTOHOTKEY = r"C:\Program Files\AutoHotkey\AutoHotkey.exe"


def execute_ahk(function_name, *args):
    """AHKスクリプトの関数を実行してJSON結果を取得"""
    cmd = [AUTOHOTKEY, AHK_SCRIPT, function_name] + list(args)
    with ahk_lock:
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=10,
                encoding='cp932'
            )
            if result.returncode == 0:
                return json.loads(result.stdout)
            else:
                return {"error": result.stderr}
        except subprocess.TimeoutExpired:
            return {"error": "HAMLOG operation timeout"}
        except json.JSONDecodeError:
            return {"error": "Invalid JSON response", "raw": result.stdout}
        except Exception as e:
            return {"error": str(e)}


@app.route('/api/status', methods=['GET'])
def get_status():
    """HAMLOGの起動状態を確認"""
    result = execute_ahk("CheckStatus")
    return jsonify(result)


@app.route('/api/callsign', methods=['GET'])
def get_callsign_data():
    """コールサインでHAMLOGからデータ取得（?q=コールサイン）"""
    callsign = request.args.get('q', '').strip()
    if not callsign:
        return jsonify({"error": "q parameter is required"}), 400
    result = execute_ahk("GetCallsignData", callsign)
    return jsonify(result)


@app.route('/api/log', methods=['POST'])
def create_log():
    """HAMLOGに新規ログを追加"""
    data = request.get_json()
    
    # 必須フィールドチェック
    if not data or 'callsign' not in data:
        return jsonify({"error": "callsign is required"}), 400
    
    # JSON文字列として渡す
    result = execute_ahk("CreateLog", json.dumps(data))
    return jsonify(result)


@app.route('/api/log', methods=['PUT'])
def update_log():
    """HAMLOGのログを更新"""
    data = request.get_json()
    result = execute_ahk("UpdateLog", json.dumps(data))
    return jsonify(result)


@app.route('/api/clear', methods=['POST'])
def clear_log():
    """HAMLOGのLOGダイアログをクリア"""
    result = execute_ahk("ClearLog")
    return jsonify(result)


@app.errorhandler(404)
def not_found(error):
    return jsonify({"error": "Endpoint not found"}), 404


@app.errorhandler(500)
def internal_error(error):
    return jsonify({"error": "Internal server error"}), 500


if __name__ == '__main__':
    # ポート8669で起動
    app.run(host='0.0.0.0', port=8669, debug=True)
