#!/usr/bin/env bash
#
# Regenerate the README pet-state GIFs (docs/states/*.gif).
#
# The app itself renders each state's animation offscreen via the real desktop
# view (`--render-gifs`, see Sources/KeyboardPet/Tools/GIFRenderer.swift), so the
# exported GIFs match the on-screen crab exactly — sweat drops, zzz, fireworks,
# WPM readout and all. This script just drives that and encodes the PNG frame
# sequences into looping, transparent GIFs with ffmpeg.
#
# Re-run it whenever you change the sprites or the effect drawing code.
#
# Requirements: a Swift toolchain and ffmpeg (brew install ffmpeg).
#
# Usage:
#   ./Tools/render_state_gifs.sh
set -euo pipefail

cd "$(dirname "$0")/.."

FPS=25          # must match GIFRenderer.fps
SIZE=240        # output GIF width/height in px
FRAMES_DIR="$(mktemp -d)"
OUT_DIR="docs/states"
mkdir -p "$OUT_DIR"

echo "==> Building app"
swift build

BIN="$(swift build --show-bin-path)/KeyboardPet"

echo "==> Rendering frames -> $FRAMES_DIR"
"$BIN" --render-gifs "$FRAMES_DIR"

echo "==> Encoding GIFs -> $OUT_DIR"
for d in "$FRAMES_DIR"/*/; do
  state="$(basename "$d")"
  ffmpeg -y -loglevel error -framerate "$FPS" -i "$d/frame_%04d.png" \
    -filter_complex "scale=${SIZE}:${SIZE}:flags=lanczos,split[a][b];[a]palettegen=reserve_transparent=1[p];[b][p]paletteuse=alpha_threshold=128" \
    -loop 0 "$OUT_DIR/$state.gif"
  echo "    $state.gif"
done

rm -rf "$FRAMES_DIR"
echo "==> Done."
