#!/usr/bin/env bash
#
# Build the KeyboardPet product demo video (docs/KeyboardPet-demo.mp4).
#
# Pipeline:
#   1. render_pet_frames.py   -> crisp 1000x1000 pet PNG sequences (real 64px
#                                sprites, nearest-neighbor — matches the app)
#   2. render_scene_cards.py  -> 1080p SVG scene cards (captions, progress bar)
#   3. ffmpeg                 -> overlay pet onto each card, fade, concat -> mp4
#
# Requirements (macOS): ffmpeg, python3 with `pillow` and `cairosvg`
#   brew install ffmpeg && pip3 install pillow cairosvg
#
# Usage:
#   ./Tools/demo_video/build.sh        # writes docs/KeyboardPet-demo.mp4
#   KEEP=1 ./Tools/demo_video/build.sh # keep the intermediate work dir
set -euo pipefail

cd "$(dirname "$0")"
HERE="$(pwd)"
REPO="$(cd ../.. && pwd)"
OUT="$REPO/docs/KeyboardPet-demo.mp4"
POSTER="$REPO/docs/demo-poster.png"

command -v ffmpeg >/dev/null || { echo "error: ffmpeg not found (brew install ffmpeg)"; exit 1; }
python3 -c "import PIL, cairosvg" 2>/dev/null || { echo "error: pip3 install pillow cairosvg"; exit 1; }

WORK="$(mktemp -d)"
export KP_WORK="$WORK"
FADE=0.3
PX=110; PY=50   # pet overlay position (1000x1000 onto 1920x1080)

echo "==> Rendering pet frames"
python3 "$HERE/render_pet_frames.py"
echo "==> Rendering scene cards"
python3 "$HERE/render_scene_cards.py"

echo "==> Composing segments"
: > "$WORK/list.txt"
while IFS='|' read -r idx pet dur; do
  seg="$WORK/seg${idx}.mp4"
  fout="$(echo "$dur - $FADE" | bc)"
  if [ "$pet" = "-" ]; then
    ffmpeg -nostdin -y -v error -loop 1 -t "$dur" -i "$WORK/bg${idx}.png" \
      -vf "fade=t=in:st=0:d=${FADE},fade=t=out:st=${fout}:d=${FADE},format=yuv420p" \
      -r 30 -c:v libx264 -pix_fmt yuv420p -crf 16 "$seg"
  else
    ffmpeg -nostdin -y -v error -loop 1 -t "$dur" -i "$WORK/bg${idx}.png" \
      -framerate 30 -i "$WORK/pet/${pet}/f_%04d.png" \
      -filter_complex "[0:v][1:v]overlay=${PX}:${PY}:eof_action=repeat,\
fade=t=in:st=0:d=${FADE},fade=t=out:st=${fout}:d=${FADE},format=yuv420p[v]" \
      -map "[v]" -t "$dur" -r 30 -c:v libx264 -pix_fmt yuv420p -crf 16 "$seg"
  fi
  echo "file '$seg'" >> "$WORK/list.txt"
  echo "    seg${idx} (${dur}s)"
done < "$WORK/manifest.txt"

echo "==> Concatenating -> $OUT"
ffmpeg -nostdin -y -v error -f concat -safe 0 -i "$WORK/list.txt" -c copy "$OUT"

echo "==> Poster -> $POSTER"
ffmpeg -nostdin -y -v error -ss 1.3 -i "$WORK/seg8.mp4" -frames:v 1 "$POSTER"

ffprobe -v error -show_entries format=duration -show_entries stream=width,height \
  -of "default=nw=1" "$OUT" | sort -u
echo "==> Done."
[ "${KEEP:-0}" = "1" ] || rm -rf "$WORK"
