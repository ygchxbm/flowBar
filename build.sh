#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGURATION="${1:-release}"
case "$CONFIGURATION" in
    debug|release) ;;
    *) echo "Usage: $0 [debug|release]" >&2; exit 2 ;;
esac
APP_DIR="$ROOT_DIR/.build/FlowBar.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"

BUILD_OPTIONS=(--disable-sandbox -c "$CONFIGURATION")
if [[ "$CONFIGURATION" == "release" ]]; then
    BUILD_OPTIONS+=(-debug-info-format none)
fi
swift build "${BUILD_OPTIONS[@]}"

BIN_DIR="$(swift build --disable-sandbox -c "$CONFIGURATION" --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
cp "$BIN_DIR/FlowBar" "$MACOS_DIR/FlowBar"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/FlowBarIcon.icns" "$RESOURCES_DIR/FlowBarIcon.icns"
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --strict "$APP_DIR"

echo "$APP_DIR"
