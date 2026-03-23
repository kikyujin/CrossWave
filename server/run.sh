#!/bin/bash
# Open Logbook - Flask API サーバー起動スクリプト
set -euo pipefail

cd "$(dirname "$0")"

source venv/bin/activate
export BONELESSHAM_API="${BONELESSHAM_API:-http://b760itx.chihuahua-platy.ts.net:8669}"

exec python app.py "$@"
