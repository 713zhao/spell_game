#!/usr/bin/env bash
# Downloads the live production SQLite database from the Fly.io
# `spellbackend` app to SpellBackend/backups/, timestamped. Read-only on
# the server - never touches production data.
#
# Requires:
#   - flyctl installed (https://fly.io/install.sh) and on PATH
#   - `flyctl auth login` done at least once, OR FLY_API_TOKEN set in the
#     environment (e.g. from `flyctl tokens create deploy -a spellbackend -x 1h`)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$ROOT_DIR/SpellBackend/backups"
APP="spellbackend"
REMOTE_DB="/database/db.sqlite3"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
OUT_FILE="$BACKUP_DIR/db.sqlite3.prod-$TIMESTAMP"

if ! command -v flyctl >/dev/null 2>&1; then
  echo "flyctl not found. Install it with:"
  echo "  curl -L https://fly.io/install.sh | sh"
  echo "  export FLYCTL_INSTALL=\"\$HOME/.fly\"; export PATH=\"\$FLYCTL_INSTALL/bin:\$PATH\""
  exit 1
fi

if [ -z "${FLY_API_TOKEN:-}" ] && ! flyctl auth whoami >/dev/null 2>&1; then
  echo "Not logged into Fly.io. Either run:"
  echo "  flyctl auth login"
  echo "or set FLY_API_TOKEN to a token from:"
  echo "  flyctl tokens create deploy -a $APP -x 1h"
  exit 1
fi

mkdir -p "$BACKUP_DIR"

# The app auto-stops its machine when idle (see fly.toml); sftp needs it
# running, so start it and wait briefly if it's currently stopped.
MACHINE_ID="$(flyctl machine list -a "$APP" --json 2>/dev/null | jq -r '.[0].id')"
STATE="$(flyctl machine list -a "$APP" --json 2>/dev/null | jq -r '.[0].state')"
if [ "$STATE" != "started" ]; then
  echo "Machine is $STATE - starting it..."
  flyctl machine start "$MACHINE_ID" -a "$APP" >/dev/null
  for i in $(seq 1 15); do
    STATE="$(flyctl machine list -a "$APP" --json 2>/dev/null | jq -r '.[0].state')"
    [ "$STATE" = "started" ] && break
    sleep 2
  done
fi

echo "Downloading $REMOTE_DB from $APP..."
flyctl ssh sftp get "$REMOTE_DB" "$OUT_FILE" -a "$APP"

echo "Saved to: $OUT_FILE"
echo "(gitignored - SpellBackend/backups/ never gets committed since this is real user data)"
