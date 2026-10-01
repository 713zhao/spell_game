#!/usr/bin/env bash
# Backs up the live production SQLite DB from the Fly.io `spellbackend` app
# to this PC (default ~/Projects/spelldbbackup), timestamped, keeping the
# newest $KEEP_DAYS days. Safe on a live DB: the copy is made server-side
# with SQLite's online-backup API, then downloaded and integrity-checked.
# Read-only for production data.
#
# Usage: backup-db.sh            # always back up
#        backup-db.sh --daily    # skip if a backup from today already exists
# Env:   BACKUP_DIR, KEEP_DAYS (default 30), FLY_API_TOKEN (optional)
set -euo pipefail
export PATH="$HOME/.fly/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

APP="spellbackend"
REMOTE_DB="/database/db.sqlite3"
REMOTE_TMP="/tmp/db-backup.sqlite3"
BACKUP_DIR="${BACKUP_DIR:-$HOME/Projects/spelldbbackup}"
KEEP_DAYS="${KEEP_DAYS:-30}"
TS="$(date +%Y%m%d-%H%M%S)"
OUT="$BACKUP_DIR/db.sqlite3.prod-$TS"
LOG="$BACKUP_DIR/backup.log"

mkdir -p "$BACKUP_DIR"; chmod 700 "$BACKUP_DIR"
log() { echo "$(date '+%F %T') $*" | tee -a "$LOG"; }

if [ "${1:-}" = "--daily" ] && ls "$BACKUP_DIR"/db.sqlite3.prod-"$(date +%Y%m%d)"-* >/dev/null 2>&1; then
  exit 0
fi
command -v flyctl >/dev/null || { log "ERROR flyctl not found"; exit 1; }
if [ -z "${FLY_API_TOKEN:-}" ] && ! flyctl auth whoami >/dev/null 2>&1; then
  log "ERROR not logged in to Fly (flyctl auth login)"; exit 1
fi

# The app auto-stops when idle; start it if needed.
read -r MACHINE_ID STATE < <(flyctl machine list -a "$APP" --json | jq -r '.[0] | "\(.id) \(.state)"')
if [ "$STATE" != "started" ]; then
  log "machine $STATE - starting"
  flyctl machine start "$MACHINE_ID" -a "$APP" >/dev/null
  for _ in $(seq 1 20); do
    [ "$(flyctl machine list -a "$APP" --json | jq -r '.[0].state')" = "started" ] && break
    sleep 3
  done
fi

PYCMD="import sqlite3;s=sqlite3.connect('$REMOTE_DB');d=sqlite3.connect('$REMOTE_TMP');s.backup(d);d.close()"
flyctl ssh console -a "$APP" -C "rm -f $REMOTE_TMP"  >/dev/null 2>&1 || true
flyctl ssh console -a "$APP" -C "python3 -c \"$PYCMD\"" >/dev/null
flyctl ssh sftp get "$REMOTE_TMP" "$OUT" -a "$APP" >/dev/null
flyctl ssh console -a "$APP" -C "rm -f $REMOTE_TMP" >/dev/null 2>&1 || true

if [ "$(python3 -c "import sqlite3,sys;print(sqlite3.connect(sys.argv[1]).execute('pragma integrity_check').fetchone()[0])" "$OUT")" != "ok" ]; then
  log "ERROR integrity check failed, removing $OUT"; rm -f "$OUT"; exit 1
fi
chmod 600 "$OUT"
log "OK $OUT ($(du -h "$OUT" | cut -f1))"

# Retention
find "$BACKUP_DIR" -name 'db.sqlite3.prod-*' -mtime +"$KEEP_DAYS" -delete
