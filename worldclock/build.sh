#!/usr/bin/env bash
# builds WorldClock.app into ~/Applications and starts it

set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/WorldClock.app"

pkill -x WorldClock || true
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp "$SRC/Info.plist" "$APP/Contents/Info.plist"

swiftc -O \
  -target arm64-apple-macos13.0 \
  -o "$APP/Contents/MacOS/WorldClock" \
  "$SRC/WorldClock.swift"

codesign --force --sign - "$APP"

open "$APP"
echo "built $APP"
