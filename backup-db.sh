#!/usr/bin/env bash
# Backs up the live production SQLite DB from the Fly.io `spellbackend` app
# to this PC (default ~/Projects/spelldbbackup), timestamped, deleting
# backups older than $KEEP_DAYS days (but always keeping the newest $KEEP_MIN),
# and skipping the save when nothing changed since the latest backup. Safe on a live DB: the copy is made server-side
# with SQLite's online-backup API, then downloaded and integrity-checked.
# Read-only for production data.
#
# Usage: backup-db.sh            # check now
#        backup-db.sh --daily    # at most one check per calendar day
# Env:   BACKUP_DIR, KEEP_DAYS (365), KEEP_MIN (5), FLY_API_TOKEN (optional)
set -euo pipefail
export PATH="$HOME/.fly/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

APP="spellbackend"
REMOTE_DB="/database/db.sqlite3"
REMOTE_TMP="/tmp/db-backup.sqlite3"
BACKUP_DIR="${BACKUP_DIR:-$HOME/Projects/spelldbbackup}"
KEEP_DAYS="${KEEP_DAYS:-365}"
KEEP_MIN="${KEEP_MIN:-5}"   # always keep at least this many newest backups
TS="$(date +%Y%m%d-%H%M%S)"
OUT="$BACKUP_DIR/db.sqlite3.prod-$TS"
LOG="$BACKUP_DIR/backup.log"

mkdir -p "$BACKUP_DIR"; chmod 700 "$BACKUP_DIR"
log() { echo "$(date '+%F %T') $*" | tee -a "$LOG"; }

MARK="$BACKUP_DIR/.checked-$(date +%Y%m%d)"
if [ "${1:-}" = "--daily" ] && [ -e "$MARK" ]; then
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
# Skip if the data is identical to the latest backup (compares the logical
# content, not file bytes/mtime, so SQLite page-level noise can't fool it).
dbhash() { python3 -c "import sqlite3,sys,hashlib;h=hashlib.sha256()
for l in sqlite3.connect(sys.argv[1]).iterdump(): h.update(l.encode())
print(h.hexdigest())" "$1"; }
PREV="$(ls -1 "$BACKUP_DIR"/db.sqlite3.prod-* 2>/dev/null | grep -v -F "$OUT" | tail -1 || true)"
if [ -n "$PREV" ] && [ "$(dbhash "$OUT")" = "$(dbhash "$PREV")" ]; then
  rm -f "$OUT"; touch "$MARK"
  log "SKIP no changes since $(basename "$PREV")"
  find "$BACKUP_DIR" -name '.checked-*' -mtime +7 -delete
  exit 0
fi
chmod 600 "$OUT"
touch "$MARK"
log "OK $OUT ($(du -h "$OUT" | cut -f1))"

# Retention: delete backups older than KEEP_DAYS, but never the newest KEEP_MIN
ls -1t "$BACKUP_DIR"/db.sqlite3.prod-* | tail -n +"$((KEEP_MIN + 1))" | while read -r f; do
  [ -n "$(find "$f" -mtime +"$KEEP_DAYS")" ] && rm -f "$f" && log "pruned $(basename "$f")"
done
find "$BACKUP_DIR" -name '.checked-*' -mtime +7 -delete
exit 0
