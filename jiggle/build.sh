#!/usr/bin/env bash
# builds Jiggle.app into ~/Applications

set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/Jiggle.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$SRC/Info.plist" "$APP/Contents/Info.plist"
cp "$SRC"/assets/*.png "$APP/Contents/Resources/"

swiftc -O \
  -target arm64-apple-macos13.0 \
  -o "$APP/Contents/MacOS/Jiggle" \
  "$SRC/Jiggle.swift"

# ad-hoc signature keeps the Accessibility grant stable across rebuilds
codesign --force --sign - "$APP"

echo "built $APP"
