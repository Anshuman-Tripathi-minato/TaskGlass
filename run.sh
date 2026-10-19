#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
PORT="${TASKGLASS_PORT:-8765}"
python3 server.py >/tmp/taskglass-server.log 2>&1 &
SERVER_PID=$!
cleanup(){ kill "$SERVER_PID" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
for i in $(seq 1 40); do
  if curl -fsS "http://127.0.0.1:${PORT}/api/state" >/dev/null 2>&1; then break; fi
  sleep 0.1
done
exec chromium --app="http://127.0.0.1:${PORT}/" --start-maximized --no-first-run --no-default-browser-check "$@"
