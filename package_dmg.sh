#!/usr/bin/env bash
#
# Build KeyboardPet and package it into a distributable .dmg with a drag-to-
# Applications layout.
#
# Usage:
#   ./package_dmg.sh            # writes KeyboardPet-<version>.dmg
#   ./package_dmg.sh dist/      # writes into the given output directory
#
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="KeyboardPet"
APP_DIR="${APP_NAME}.app"
OUT_DIR="${1:-.}"

# Build the (ad-hoc signed) .app bundle.
./build_app.sh

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${APP_DIR}/Contents/Info.plist")"
DMG_PATH="${OUT_DIR%/}/${APP_NAME}-${VERSION}.dmg"
mkdir -p "${OUT_DIR}"

echo "▶︎ Staging disk image contents…"
STAGING="$(mktemp -d)/${APP_NAME}"
mkdir -p "${STAGING}"
cp -R "${APP_DIR}" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"

echo "▶︎ Creating ${DMG_PATH}…"
rm -f "${DMG_PATH}"
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGING}" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "${DMG_PATH}" >/dev/null

rm -rf "$(dirname "${STAGING}")"

echo "✅ Wrote ${DMG_PATH}"
