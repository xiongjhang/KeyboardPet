# Contributing to KeyboardPet

Thanks for your interest in improving KeyboardPet! This is a small, focused
macOS app and contributions of all sizes are welcome.

## Getting started

```bash
git clone https://github.com/xiongjhang/KeyboardPet.git
cd KeyboardPet

swift build            # debug build
swift test             # run the test suite
./build_app.sh --run   # build the .app bundle and launch it
```

The app must run from a `.app` bundle to receive Accessibility permission (the
global keyboard monitor needs it). See the README for the first-launch grant
flow.

## Development notes

- **Requirements:** macOS 14+ and a Swift 5.9+ toolchain (Xcode 15+).
- **Architecture:** the keyboard monitor → metrics engine → state machine
  pipeline lives in `Sources/KeyboardPet/Core`, wired together by
  `App/PetController`. UI is SwiftUI under `View/`.
- **Privacy is a hard constraint.** KeyboardPet records only physical key codes
  and timestamps, and makes no network connections. Please do not add anything
  that captures typed characters, window titles, app names, or that phones home.
- **Keep it light.** It's an always-on menu-bar agent; be mindful of CPU and
  memory. Per-keystroke work should stay cheap; persistence is batched.

## Pull requests

1. Branch off `main`.
2. Keep changes focused; one logical change per PR.
3. Run `swift build` and `swift test` before pushing.
4. Match the surrounding code style (naming, comment density, idioms).
5. Update `CHANGELOG.md` under `## [Unreleased]` when your change is
   user-visible.

### Commit messages

Commit messages are written in **English** and follow a
[Conventional Commits](https://www.conventionalcommits.org/)-style prefix,
e.g. `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`.

## Reporting bugs / requesting features

Please use the issue templates. Include your macOS version and, for bugs, the
steps to reproduce.
