#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIGURATION="${1:-release}"
APP_DIR="$ROOT_DIR/.build/FlowBar.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"

swift build --disable-sandbox -c "$CONFIGURATION" -debug-info-format none

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/$CONFIGURATION/FlowBar" "$MACOS_DIR/FlowBar"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/FlowBarIcon.icns" "$RESOURCES_DIR/FlowBarIcon.icns"
codesign --force --deep --sign - "$APP_DIR"

echo "$APP_DIR"
