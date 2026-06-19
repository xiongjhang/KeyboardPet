# Demo video builder

Builds the product demo video at [`docs/KeyboardPet-demo.mp4`](../../docs/KeyboardPet-demo.mp4)
(1920×1080, 30 fps) and a poster frame at `docs/demo-poster.png`.

The crab is **not** the README GIFs — those are downscaled with lanczos and look
soft. Instead this re-renders the pet from the real 64×64 sprite art with
nearest-neighbor scaling, exactly like the app does on screen
(`imageSmoothingEnabled = false` / `.interpolation(.none)`), so it stays crisp.

## Run

```bash
brew install ffmpeg
pip3 install pillow cairosvg
./Tools/demo_video/build.sh          # -> docs/KeyboardPet-demo.mp4 + docs/demo-poster.png
KEEP=1 ./Tools/demo_video/build.sh   # keep the intermediate work dir for debugging
```

macOS only (uses the system fonts SF Pro Rounded and Hiragino Sans GB).

## Layout

```
build.sh                  driver: deps check, render, ffmpeg compose + concat
render_pet_frames.py      crisp 1000×1000 pet PNG sequences  (port of tauri/src/main.js)
render_scene_cards.py     1080p SVG scene cards (captions, progress bar)
sprites/                  the 64×64 source sprites the renderer needs (self-contained)
```

`render_pet_frames.py` is a faithful Python/PIL port of the app's pet renderer
(`tauri/src/main.js`, itself a 1:1 port of the Swift `ClawdSpriteContent` +
`ClawdEffects` + `PixelFont`): sprite frames, bob/breathing motion, the WPM
readout, fireworks, sweat drops, `zzz`, and sparkles. Keep it in sync if you
change the on-screen renderer.

## Editing the script

- **Scenes / captions / durations** — edit the `scenes` list in
  `render_scene_cards.py` and `JOBS` in `render_pet_frames.py` (durations must
  stay ≥ the matching scene length).
- **Sprites** — `sprites/` is a copy of `tauri/src/assets/clawd/*.png` (day
  states only). Re-copy if the artwork changes. The bundled `night_*` sprites
  are intentionally omitted; add them here and a night scene to feature them.
