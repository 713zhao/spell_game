#!/usr/bin/env bash
# Kills whatever is listening on the backend/frontend dev ports, then
# restarts all three in the background with logs under logs/ so
# hot-reload output stays visible via `tail -f`.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$ROOT_DIR/logs"
PID_DIR="$ROOT_DIR/.pids"
mkdir -p "$LOG_DIR" "$PID_DIR"

BACKEND_PORT=8090
FRONTEND_PORT=8080
FRONTEND2_PORT=8081
# FlutterSpell_Game builds URLs as "$baseUrl/path" (no trailing slash expected).
API_BASE_URL_GAME="http://localhost:${BACKEND_PORT}"
# FlutterSpell builds URLs as "${baseUrl}path" (trailing slash required).
API_BASE_URL_SPELL="http://localhost:${BACKEND_PORT}/"

killport() {
  local port="$1"
  local pids
  pids="$(lsof -ti tcp:"$port" 2>/dev/null || true)"
  if [ -n "$pids" ]; then
    echo "  killing PID(s) $pids on port $port"
    kill -9 $pids 2>/dev/null || true
  fi
}

echo "Stopping backend (port $BACKEND_PORT)..."
killport "$BACKEND_PORT"

echo "Stopping frontend (port $FRONTEND_PORT)..."
killport "$FRONTEND_PORT"

echo "Stopping frontend (port $FRONTEND2_PORT)..."
killport "$FRONTEND2_PORT"

echo "Starting backend (SpellBackend, port $BACKEND_PORT)..."
(
  cd "$ROOT_DIR/SpellBackend"
  if [ ! -d .venv ]; then
    python3 -m venv .venv
    ./.venv/bin/pip install -q -r requirements.txt
  fi
  SERVER_PORT=$BACKEND_PORT ./.venv/bin/python main.py > "$LOG_DIR/backend.log" 2>&1 &
  echo $! > "$PID_DIR/backend.pid"
)

echo "Starting frontend (FlutterSpell_Game, port $FRONTEND_PORT)..."
(
  cd "$ROOT_DIR/FlutterSpell_Game"
  flutter run -d web-server --web-port="$FRONTEND_PORT" --web-hostname=0.0.0.0 \
    --dart-define=API_BASE_URL="$API_BASE_URL_GAME" > "$LOG_DIR/flutterspell_game.log" 2>&1 &
  echo $! > "$PID_DIR/flutterspell_game.pid"
)

echo "Starting frontend (FlutterSpell, port $FRONTEND2_PORT)..."
(
  cd "$ROOT_DIR/FlutterSpell"
  flutter run -d web-server --web-port="$FRONTEND2_PORT" --web-hostname=0.0.0.0 \
    --dart-define=API_BASE_URL="$API_BASE_URL_SPELL" > "$LOG_DIR/flutterspell.log" 2>&1 &
  echo $! > "$PID_DIR/flutterspell.pid"
)

echo "Done."
echo "  Backend:            http://localhost:$BACKEND_PORT           (logs/backend.log)"
echo "  FlutterSpell_Game:  http://localhost:$FRONTEND_PORT           (logs/flutterspell_game.log)"
echo "  FlutterSpell:       http://localhost:$FRONTEND2_PORT           (logs/flutterspell.log)"
echo "Tail all logs with: tail -f logs/*.log"
