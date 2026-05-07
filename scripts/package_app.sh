#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="IPLoc"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
UNIVERSAL="${UNIVERSAL:-0}"

if [[ "${1:-}" == "--universal" ]]; then
  UNIVERSAL="1"
fi

cd "$ROOT_DIR"

if [[ "$UNIVERSAL" == "1" ]]; then
  swift build -c release --product IPLoc --arch arm64 --arch x86_64
  BINARY_PATH="$ROOT_DIR/.build/apple/Products/Release/IPLoc"
else
  BIN_DIR="$(swift build -c release --product IPLoc --show-bin-path)"
  swift build -c release --product IPLoc
  BINARY_PATH="$BIN_DIR/IPLoc"
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BINARY_PATH" "$MACOS_DIR/IPLoc"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/IPLocIcon.icns" "$RESOURCES_DIR/IPLocIcon.icns"

chmod +x "$MACOS_DIR/IPLoc"
codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "$APP_DIR"
