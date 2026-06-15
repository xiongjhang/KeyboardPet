#!/usr/bin/env bash
#
# Build KeyboardPet and package it into a runnable .app bundle.
#
# Usage:
#   ./build_app.sh          # release build + bundle
#   ./build_app.sh --run    # build, bundle, then launch
#
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="KeyboardPet"
CONFIG="release"
APP_DIR="${APP_NAME}.app"
MACOS_DIR="${APP_DIR}/Contents/MacOS"
RES_DIR="${APP_DIR}/Contents/Resources"

echo "▶︎ Building (${CONFIG})…"
swift build -c "${CONFIG}"

BIN_PATH="$(swift build -c "${CONFIG}" --show-bin-path)/${APP_NAME}"

echo "▶︎ Assembling ${APP_DIR}…"
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RES_DIR}"
cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"
cp "Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"

# Copy SwiftPM resource bundles (sprite assets) next to the binary so
# `Bundle.module` resolves them at runtime.
BIN_DIR="$(swift build -c "${CONFIG}" --show-bin-path)"
for bundle in "${BIN_DIR}"/*.bundle; do
    [ -e "${bundle}" ] && cp -R "${bundle}" "${MACOS_DIR}/"
done

# Ad-hoc sign so the Accessibility grant sticks for this build.
echo "▶︎ Code signing (ad-hoc)…"
codesign --force --sign - "${APP_DIR}" >/dev/null 2>&1 || true

echo "✅ Built ${APP_DIR}"

if [[ "${1:-}" == "--run" ]]; then
    echo "▶︎ Launching…"
    open "${APP_DIR}"
fi
