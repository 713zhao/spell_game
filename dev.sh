#!/usr/bin/env bash
# Runs the backend (auto-reload) in the background and the Flutter app in
# the foreground with hot reload. Once the app is running, press 'r' in
# this terminal to hot reload after saving a file, 'R' for a full hot
# restart, or 'q' to quit - quitting also stops the backend.
#
# Usage: ./dev.sh [device-id]
#   Defaults to Chrome. Run `flutter devices` to see other options (e.g.
#   linux for the desktop build).
set -e
cd "$(dirname "$0")"

./SpellBackend/dev.sh &
BACKEND_PID=$!
trap 'kill "$BACKEND_PID" 2>/dev/null' EXIT

# Give the backend a moment to come up before the app's first request.
sleep 1

DEVICE="${1:-chrome}"
(cd FlutterSpell_Game && flutter run -d "$DEVICE")
