# KeyboardPet 🐾⌨️

A macOS desktop pet driven by your real keyboard activity. It watches your typing
rhythm (privately — only physical key codes, never characters) and reacts: typing,
flow, frantic deleting, dozing off, celebrating new records, and more.

See [DESIGN.md](DESIGN.md) for the full design.

## Requirements

- macOS 14 (Sonoma) or later
- Swift 5.9+ toolchain (Xcode 15+ / command-line tools)

## Build & Run

The app must run from a `.app` bundle so macOS can grant it Accessibility
permission (required for global keyboard monitoring).

```bash
# Build the .app bundle and launch it
./build_app.sh --run

# Or build only
./build_app.sh
open KeyboardPet.app
```

### First launch: grant Accessibility permission

1. On first launch, macOS prompts for **Accessibility** permission.
2. Open **System Settings ▸ Privacy & Security ▸ Accessibility**.
3. Enable **KeyboardPet**.
4. The pet starts reacting to your typing immediately (no relaunch needed).

If you rebuild, you may need to re-toggle the permission (ad-hoc signing changes
the app identity each build).

### Using the pet

- The pet floats above other windows in the bottom-right corner.
- **Drag** it anywhere — its position is remembered.
- Quit via the menu bar icon (added in M4) or **Cmd-Q**.

## Development (SwiftPM)

```bash
swift build          # debug build
swift build -c release
```

## Privacy

KeyboardPet records **only** physical key codes and timestamps, used purely to
compute aggregate metrics (WPM, delete rate, idle time). It never records typed
characters, window titles, or app names, and never connects to the network.
