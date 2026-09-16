#!/usr/bin/env bash
# Runs the Flutter app in debug mode with hot reload. Once it's running,
# press 'r' in this terminal to hot reload after saving a file, or 'R' for
# a full hot restart; 'q' quits.
#
# Usage: ./dev.sh [device-id]
#   Defaults to the Linux desktop device. Run `flutter devices` to see
#   other options (e.g. chrome).
set -e
cd "$(dirname "$0")"
DEVICE="${1:-linux}"
exec flutter run -d "$DEVICE"
