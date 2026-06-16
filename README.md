<div align="center">

<img src="docs/states/idle.gif" width="140" alt="KeyboardPet">

# KeyboardPet 🐾⌨️

**A macOS desktop pet driven by your real keyboard activity.**

It watches your typing rhythm — privately, only physical key codes, never
characters — and reacts: typing, flow, frantic deleting, dozing off,
celebrating new records, and more.

[English](README.md) · [简体中文](README.zh-CN.md)

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift)
![License](https://img.shields.io/badge/license-MIT-blue)
![Privacy](https://img.shields.io/badge/privacy-100%25%20local-brightgreen)

</div>

---

## ✨ Features

- **Driven by real typing** — A global keyboard monitor (CGEventTap) reads your
  rhythm and switches the pet between states in real time. It records *only*
  physical key codes and timestamps — never the characters you type.
- **Expressive pixel-art crab** — Nine hand-drawn states (idle, typing, flow,
  deleting, thinking, sleepy, sleeping, wakeup, record), each with its own
  motion and effects (sweat drops, `zzz`, sparkles, fireworks…).
- **Night mode** — Between 00:00–05:00 the crab puts on a baked-in nightcap and
  takes on a sleepier, dimmer look.
- **Live stats at a glance** — The menu bar icon opens a summary of level / XP,
  today's keystrokes, and current & peak WPM, plus a live WPM readout above the
  crab while you type.
- **Activity insights** — A stats panel with today's totals, an hourly activity
  heatmap, and a monthly calendar heatmap you can drill into per day.
- **Leveling & records** — Earn XP as you type, level up, and trigger a
  celebration whenever you beat your peak WPM.
- **Lightweight & unobtrusive** — A menu-bar agent with no Dock icon. The pet
  floats above other windows; drag it anywhere and its position is remembered.
- **Privacy-first** — No characters, no window titles, no app names, and no
  network access. Ever.

## 🐾 Pet states

The pet reacts to your typing in real time. The clips below are rendered from
the actual desktop view, so they match what you see on screen — sweat drops,
`zzz`, fireworks, the live WPM readout and all. During 00:00–05:00 a nightcap
overlay is baked into the sprites (a sleepier, night-mode look).

<table>
  <tr>
    <td align="center"><img src="docs/states/idle.gif" width="96" alt="idle"><br><b>idle</b><br><sub>resting, the occasional blink</sub></td>
    <td align="center"><img src="docs/states/typing.gif" width="96" alt="typing"><br><b>typing</b><br><sub>you're actively typing</sub></td>
    <td align="center"><img src="docs/states/flow.gif" width="96" alt="flow"><br><b>flow</b><br><sub>WPM &gt; 80 sustained</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/states/deleting.gif" width="96" alt="deleting"><br><b>deleting</b><br><sub>lots of backspaces</sub></td>
    <td align="center"><img src="docs/states/thinking.gif" width="96" alt="thinking"><br><b>thinking</b><br><sub>a short pause</sub></td>
    <td align="center"><img src="docs/states/sleepy.gif" width="96" alt="sleepy"><br><b>sleepy</b><br><sub>idle longer, yawning</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/states/sleeping.gif" width="96" alt="sleeping"><br><b>sleeping</b><br><sub>idle long enough to doze</sub></td>
    <td align="center"><img src="docs/states/wakeup.gif" width="96" alt="wakeup"><br><b>wakeup</b><br><sub>startle when you resume</sub></td>
    <td align="center"><img src="docs/states/record.gif" width="96" alt="record"><br><b>record</b><br><sub>celebrating a new peak WPM</sub></td>
  </tr>
</table>

<sub>Regenerate these with <code>./Tools/render_state_gifs.sh</code> after changing the sprites or effects.</sub>

## 📦 Requirements

- macOS 14 (Sonoma) or later
- Swift 5.9+ toolchain (Xcode 15+ / command-line tools)

## 🚀 Quick Start

The app must run from a `.app` bundle so macOS can grant it Accessibility
permission (required for global keyboard monitoring).

```bash
git clone https://github.com/xiongjhang/KeyboardPet.git
cd KeyboardPet

# Build the .app bundle and launch it
./build_app.sh --run

# …or build only
./build_app.sh
open KeyboardPet.app
```

### First launch: grant Accessibility permission

1. On first launch, macOS prompts for **Accessibility** permission.
2. Open **System Settings ▸ Privacy & Security ▸ Accessibility**.
3. Enable **KeyboardPet**.
4. The pet starts reacting to your typing immediately (no relaunch needed).

> If you rebuild, you may need to re-toggle the permission — ad-hoc signing
> changes the app identity on each build.

## 🖱️ Usage

- The pet floats above other windows in the bottom-right corner.
- **Drag** it anywhere — its position is remembered.
- The **menu bar icon** shows a live summary: level / XP, today's keystrokes,
  current & peak WPM. From there you can open the **stats panel** (today's
  totals, hourly heatmap, monthly calendar) or quit.
- Adjust the on-desktop crab size in **Settings**.

## 🔒 Privacy

KeyboardPet records **only** physical key codes and timestamps, used purely to
compute aggregate metrics (WPM, delete rate, idle time). It never records typed
characters, window titles, or app names, and it never connects to the network.

## 🛠️ Development

```bash
swift build              # debug build
swift build -c release   # release build
```

The pet-state GIFs in this README are produced by the app itself: a hidden
`--render-gifs <dir>` launch mode renders each state offscreen through the real
desktop view, so the exported animations match what you see on screen.
`Tools/render_state_gifs.sh` drives that and encodes the looping GIFs with
ffmpeg.

## 🗺️ Roadmap

- More skins beyond the pixel crab
- Richer growth / achievement system
- Optional weekly & monthly activity reports

## 🙏 Acknowledgments

Inspired by, and grateful to:

- [Bongo Cat Mac Keyboard](https://github.com/huxianyin/bongocat-mac-keyboard) — keyboard monitoring approach (CGEventTap)
- [Mac Pet](https://mac-pet.com/) — menu-bar integration & contribution-graph-style activity
- [Clawd on Desk](https://github.com/rullerzhou-afk/clawd-on-desk) — pixel-art state machine & sleep sequences

## 📄 License

Released under the [MIT License](LICENSE). The pixel-art crab sprites are
original artwork for this project.
