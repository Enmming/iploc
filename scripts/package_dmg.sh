#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="IPLoc"
VERSION="${1:-${GITHUB_REF_NAME:-}}"

if [[ -z "$VERSION" ]]; then
  if git -C "$ROOT_DIR" describe --tags --exact-match >/dev/null 2>&1; then
    VERSION="$(git -C "$ROOT_DIR" describe --tags --exact-match)"
  else
    VERSION="dev"
  fi
fi

VERSION="${VERSION//\//-}"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
STAGING_DIR="$ROOT_DIR/dist/dmg-root"
DMG_PATH="$ROOT_DIR/dist/$APP_NAME-$VERSION-macos.dmg"

"$ROOT_DIR/scripts/package_app.sh" --universal

if find "$APP_DIR" \( -name '*.mmdb' -o -name '*.mmdb.gz' \) -print -quit | grep -q .; then
  echo "Refusing to package bundled database files." >&2
  exit 1
fi

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

hdiutil verify "$DMG_PATH" >/dev/null
rm -rf "$STAGING_DIR"

echo "$DMG_PATH"
