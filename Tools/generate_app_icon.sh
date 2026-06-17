#!/usr/bin/env bash
#
# Regenerate Resources/AppIcon.icns from the pixel-art crab sprite.
#
# Usage:
#   ./Tools/generate_app_icon.sh
#
set -euo pipefail

cd "$(dirname "$0")/.."

SOURCE="Sources/KeyboardPet/Resources/Sprites/clawd/idle_0.png"
ICONSET="$(mktemp -d)/AppIcon.iconset"
OUT="Resources/AppIcon.icns"

echo "▶︎ Rendering iconset…"
swift Tools/GenerateAppIcon.swift "${SOURCE}" "${ICONSET}"

echo "▶︎ Packing ${OUT}…"
iconutil -c icns "${ICONSET}" -o "${OUT}"
rm -rf "$(dirname "${ICONSET}")"

echo "✅ Wrote ${OUT}"
