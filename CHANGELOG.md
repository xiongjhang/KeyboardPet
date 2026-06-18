# Changelog

All notable changes to KeyboardPet are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Launch-at-login toggle (Settings ▸ General), backed by `SMAppService`.
- "About" section in the menu bar dropdown showing the app version, with a link
  to the project page.
- Data management in Settings: export your keystroke history to JSON, and a
  destructive "erase all data" action that clears stats, XP, level and records.
- App icon (`AppIcon.icns`) generated from the pixel-art crab.
- Unit tests covering the experience curve, the state machine, the metrics
  engine and the stats date helpers.
- Continuous integration (GitHub Actions): build + test on every push/PR.
- Community docs: `CHANGELOG.md`, `CONTRIBUTING.md`, and issue / PR templates.

### Changed
- Distribution is **source-only**: building locally is the supported install
  path. Without Apple notarization a downloaded binary would trip Gatekeeper
  on every machine, so no pre-built `.dmg` is published.

### Removed
- The tag-triggered DMG release workflow and `package_dmg.sh`.

## [0.1.0] - 2026-06-17

First public release.

### Added
- Desktop pet driven by real keyboard activity via a global `CGEventTap`
  monitor (records only physical key codes and timestamps — never characters).
- Pixel-art "Clawd" crab with nine states (idle, typing, flow, deleting,
  thinking, sleepy, sleeping, wakeup, record) and per-state effects.
- Full priority-based state machine with user-tunable thresholds.
- Night mode (00:00–05:00) with a baked-in nightcap sprite variant.
- Live WPM readout above the crab while typing.
- Menu-bar agent (no Dock icon) with a live status summary.
- Stats panel: today's totals, an hourly heatmap, and a monthly calendar
  heatmap with per-day drill-down.
- Experience / level system and a peak-WPM record celebration.
- Draggable pet window with remembered position; user-adjustable crab size.
- Privacy-first design: no characters, window titles, app names, or network
  access.

[Unreleased]: https://github.com/xiongjhang/KeyboardPet/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/xiongjhang/KeyboardPet/releases/tag/v0.1.0
