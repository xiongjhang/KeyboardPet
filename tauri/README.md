# KeyboardPet — cross-platform (Tauri)

The cross-platform (Windows + macOS) rewrite of KeyboardPet, built with Tauri
(Rust backend + a plain HTML/CSS/JS frontend). The original macOS-native Swift
app still lives at the repo root; this directory is self-contained.

See [../docs/cross-platform-plan.md](../docs/cross-platform-plan.md) for the
design and the behavior baseline the Rust core mirrors 1:1.

## Layout

```
tauri/
├─ src/                  Frontend (pet window, stats & settings panels)
│  └─ assets/clawd/      Pixel-art sprites (shared with the Swift app)
└─ src-tauri/
   ├─ src/core/          Platform-independent logic (metrics, state machine,
   │                     experience, settings, stats store) — unit-tested
   ├─ src/platform/      Global keyboard hook (rdev)
   ├─ src/runtime.rs     Wires keyboard → core → frontend; persistence
   └─ src/commands.rs    Commands behind the stats/settings windows
```

## Prerequisites

- [Rust](https://www.rust-lang.org/tools/install) (stable)
- Node.js 18+
- Platform build deps per <https://tauri.app/start/prerequisites/>
  (Windows: WebView2 — preinstalled on Windows 10/11; macOS: Xcode CLT)

## Develop

```bash
cd tauri
npm install
npm run tauri dev
```

On macOS the first launch prompts for **Accessibility** permission (required for
the global keyboard hook) — grant it under System Settings ▸ Privacy & Security ▸
Accessibility, then relaunch. Windows needs **no** permission.

The crab floats bottom-right and reacts to your typing; the tray menu opens the
stats and settings windows. Stats, settings, XP, peak WPM, and the window
position all persist across launches (under the OS app-data directory).

## Test

```bash
cd tauri/src-tauri
cargo test --lib      # core + stats + keyboard-mapping unit tests
```

## Build installers

```bash
cd tauri
npm run tauri build   # outputs to src-tauri/target/release/bundle/
```

### Testing on Windows without a local toolchain

Push to the `feat/cross-platform-tauri` branch (or run the workflow manually):
the **Build (Tauri cross-platform)** GitHub Action builds on macOS *and* Windows
and uploads the installers as artifacts. Download the `keyboardpet-windows-latest`
artifact (NSIS `.exe` / MSI) and run it to test on Windows.

## Privacy

Like the Swift app, the keyboard hook derives **only** whether each press was a
delete key, plus a timestamp — it never reads the produced character, window
title, or app name, and the app makes no network requests.
