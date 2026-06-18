// Pet renderer — a 1:1 port of the Swift ClawdSpriteContent + ClawdEffects +
// PixelFont onto an HTML canvas, so the desktop crab looks pixel-for-pixel like
// the macOS app. State / WPM / night come from the Rust runtime's `pet-update`
// events; everything here is pure time-driven drawing.

const SIZE = 200; // logical canvas (matches PetWindowController.petSize)
const SPRITE = 150; // on-screen sprite size
const ASSET_BASE = "/assets/clawd";

// Anchors from the Swift ClawdEffects (200x200 window).
const CENTER = { x: 100, y: 104 };
const HEAD_TOP = 58;

// Animation FPS per state (PetState.spriteFPS).
const FPS = {
  typing: 6, deleting: 9, flow: 7, record: 6,
  idle: 0.8, thinking: 1.2, sleepy: 0.9, sleeping: 0.6, wakeup: 1,
};

// All states ship 2 frames except `wakeup` (single startle frame).
function framesFor(state, night) {
  const prefix = night ? "night_" : "";
  const stem = `${ASSET_BASE}/${prefix}${state}`;
  if (state === "wakeup") return [`${stem}_0.png`];
  return [`${stem}_0.png`, `${stem}_1.png`];
}

const ALL_STATES = [
  "idle", "typing", "flow", "deleting", "thinking",
  "sleepy", "sleeping", "wakeup", "record",
];

// Preload every frame; look them up by src.
const images = new Map();
function preloadAll() {
  for (const state of ALL_STATES) {
    for (const night of [false, true]) {
      for (const src of framesFor(state, night)) {
        const img = new Image();
        img.src = src;
        images.set(src, img);
      }
    }
  }
}

// ---- PixelFont (tiny bitmap font for the WPM readout) --------------------

const GLYPHS = {
  "0": ["111", "101", "101", "101", "111"],
  "1": ["010", "110", "010", "010", "111"],
  "2": ["111", "001", "111", "100", "111"],
  "3": ["111", "001", "111", "001", "111"],
  "4": ["101", "101", "111", "001", "001"],
  "5": ["111", "100", "111", "001", "111"],
  "6": ["111", "100", "111", "101", "111"],
  "7": ["111", "001", "010", "010", "010"],
  "8": ["111", "101", "111", "101", "111"],
  "9": ["111", "101", "111", "001", "111"],
  W: ["10001", "10001", "10101", "11011", "10001"],
  P: ["11110", "10001", "11110", "10000", "10000"],
  M: ["10001", "11011", "10101", "10001", "10001"],
  " ": ["00", "00", "00", "00", "00"],
};
const FONT_HEIGHT = 5;

function fontWidth(str, pixel, spacing = 1) {
  let w = 0;
  const chars = [...str];
  chars.forEach((ch, i) => {
    const g = GLYPHS[ch];
    if (!g) return;
    w += g[0].length * pixel;
    if (i < chars.length - 1) w += spacing * pixel;
  });
  return w;
}

function fontDraw(ctx, str, x, y, pixel, color, spacing = 1) {
  ctx.fillStyle = color;
  let cx = x;
  for (const ch of str) {
    const g = GLYPHS[ch];
    if (!g) continue;
    g.forEach((row, r) => {
      [...row].forEach((bit, c) => {
        if (bit === "1") {
          ctx.fillRect(cx + c * pixel, y + r * pixel, pixel, pixel);
        }
      });
    });
    cx += g[0].length * pixel + spacing * pixel;
  }
}

function fontDrawCentered(ctx, str, centerX, top, pixel, color, spacing = 1) {
  const w = fontWidth(str, pixel, spacing);
  fontDraw(ctx, str, centerX - w / 2, top, pixel, color, spacing);
}

// ---- helpers -------------------------------------------------------------

const rgba = (r, g, b, a) => `rgba(${r}, ${g}, ${b}, ${a})`;
const TAU = Math.PI * 2;
const frac = (x) => x - Math.floor(x); // truncatingRemainder for positive x

function ellipse(ctx, x, y, w, h, fill) {
  ctx.beginPath();
  ctx.ellipse(x + w / 2, y + h / 2, w / 2, h / 2, 0, 0, TAU);
  ctx.fillStyle = fill;
  ctx.fill();
}

function roundRect(ctx, x, y, w, h, r, fill) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
  ctx.fillStyle = fill;
  ctx.fill();
}

// A rounded, heavy "bubble" glyph (?, z, !, ✦) centered at (x, y).
function bubble(ctx, s, x, y, size, color) {
  ctx.fillStyle = color;
  ctx.font = `800 ${size}px "SF Pro Rounded", "Arial Rounded MT Bold", system-ui, sans-serif`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(s, x, y);
}

// ---- animation motion (PetTheme) ----------------------------------------

const breathing = (t) => 1.0 + 0.025 * Math.sin(t * 1.6);
const pawBob = (t, phase) => Math.sin(t * 14 + phase);
const excitedBob = (t) => Math.sin(t * 9);
const glow = (t) => 0.4 + 0.2 * Math.sin(t * 4);
function wakeupBounce(p) {
  const damp = Math.max(0, 1 - p / 2.0);
  return Math.abs(Math.sin(p * 8)) * damp * 14;
}

function bobOffset(state, t, age) {
  switch (state) {
    case "typing": return pawBob(t, 0) * 1.5;
    case "flow": return excitedBob(t) * 4;
    case "record": return excitedBob(t) * 3;
    case "wakeup": return -wakeupBounce(age);
    default: return 0;
  }
}

// ---- effects (ClawdEffects) ---------------------------------------------

function drawShadow(ctx) {
  ellipse(ctx, SIZE / 2 - 46, SIZE * 0.82, 92, 16, rgba(0, 0, 0, 0.18));
}

function drawGlow(ctx, t) {
  const r = 84;
  ellipse(ctx, CENTER.x - r, CENTER.y - r, r * 2, r * 2,
    rgba(255, 165, 0, glow(t) * 0.45));
}

function drawFireworks(ctx, t) {
  const bursts = [
    [SIZE * 0.28, SIZE * 0.22, [255, 45, 85]],
    [SIZE * 0.72, SIZE * 0.18, [255, 255, 0]],
    [SIZE * 0.5, SIZE * 0.32, [0, 255, 255]],
  ];
  bursts.forEach(([bx, by, col], i) => {
    const phase = frac(t * 0.9 + i * 0.4);
    const radius = phase * 32;
    const alpha = 1 - phase;
    for (let a = 0; a < TAU; a += Math.PI / 5) {
      const px = bx + Math.cos(a) * radius;
      const py = by + Math.sin(a) * radius;
      ellipse(ctx, px - 2.5, py - 2.5, 5, 5, rgba(col[0], col[1], col[2], alpha));
    }
  });
}

const OUTLINE = rgba(0, 0, 0, 0.82);

function drawFrontEffects(ctx, state, t) {
  switch (state) {
    case "deleting":
      [-34, 34].forEach((dx, i) => {
        const phase = frac(t * 2 + i * 0.5);
        const y = HEAD_TOP + phase * 30;
        ellipse(ctx, CENTER.x + dx, y, 8, 11, rgba(102, 179, 255, 1 - phase));
      });
      break;
    case "thinking":
      bubble(ctx, "?", CENTER.x + 56, HEAD_TOP - 4, 30, OUTLINE);
      break;
    case "sleeping": {
      const baseX = CENTER.x + 44, baseY = HEAD_TOP;
      for (let i = 0; i < 3; i++) {
        const phase = frac(t * 0.6 + i * 0.33);
        const x = baseX + phase * 26;
        const y = baseY - phase * 42;
        bubble(ctx, "z", x, y, 14 + i * 5, rgba(0, 0, 0, 0.82 * (1 - phase)));
      }
      break;
    }
    case "wakeup":
      bubble(ctx, "!", CENTER.x + 48, HEAD_TOP - 10, 34, rgba(255, 0, 0, 1));
      break;
    case "flow": {
      const positions = [[-62, -34], [60, -26], [-52, 32], [56, 38]];
      positions.forEach(([dx, dy], i) => {
        const twinkle = Math.abs(Math.sin(t * 3 + i));
        bubble(ctx, "✦", CENTER.x + dx, CENTER.y + dy,
          12 + twinkle * 8, rgba(255, 255, 0, 0.6 + twinkle * 0.4));
      });
      break;
    }
  }
}

function showsWPM(state) {
  return state === "typing" || state === "flow" || state === "deleting" || state === "record";
}

function wpmColor(wpm) {
  if (wpm < 40) return [140, 217, 179]; // calm green
  if (wpm < 80) return [255, 209, 77]; // warm yellow
  return [255, 115, 77]; // hot orange (flow)
}

function drawWPM(ctx, wpm, t) {
  const numStr = `${wpm}`;
  const numPixel = 4, unitPixel = 2, numTop = 12;
  const numW = fontWidth(numStr, numPixel);
  const unitStr = "WPM";
  const unitW = fontWidth(unitStr, unitPixel);
  const unitTop = numTop + FONT_HEIGHT * numPixel + 5;
  const [r, g, b] = wpmColor(wpm);

  // Backing panel so the readout stays legible over any wallpaper.
  const contentW = Math.max(numW, unitW);
  const panelX = CENTER.x - contentW / 2 - 8;
  const panelY = numTop - 6;
  const panelW = contentW + 16;
  const panelH = unitTop + FONT_HEIGHT * unitPixel + 6 - (numTop - 6);
  roundRect(ctx, panelX, panelY, panelW, panelH, 5, rgba(0, 0, 0, 0.32));

  // Number, with a 1px dark drop-shadow for contrast.
  fontDrawCentered(ctx, numStr, CENTER.x + 1, numTop + 1, numPixel, rgba(0, 0, 0, 0.5));
  fontDrawCentered(ctx, numStr, CENTER.x, numTop, numPixel, rgba(r, g, b, 1));
  // Unit label.
  fontDrawCentered(ctx, unitStr, CENTER.x, unitTop, unitPixel, rgba(r, g, b, 0.85));
}

// ---- main loop -----------------------------------------------------------

let current = { state: "idle", is_night: false, wpm: 0 };
let stateChangedAt = 0;

function drawSprite(ctx, state, isNight, t) {
  const frames = framesFor(state, isNight);
  const fps = FPS[state] ?? 1;
  const idx = Math.floor(t * fps) % frames.length;
  const img = images.get(frames[idx]);
  if (!img || !img.complete || img.naturalWidth === 0) return;

  const age = Math.max(0, t - stateChangedAt);
  const bob = bobOffset(state, t, age);
  const scale = state === "idle" ? breathing(t) : 1.0;

  ctx.save();
  ctx.translate(CENTER.x, 100 + bob);
  ctx.scale(scale, scale);
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(img, -SPRITE / 2, -SPRITE / 2, SPRITE, SPRITE);
  ctx.restore();
}

window.addEventListener("DOMContentLoaded", () => {
  const canvas = document.querySelector("#pet");
  const dpr = window.devicePixelRatio || 1;
  canvas.width = SIZE * dpr;
  canvas.height = SIZE * dpr;
  canvas.style.width = `${SIZE}px`;
  canvas.style.height = `${SIZE}px`;
  const ctx = canvas.getContext("2d");
  ctx.scale(dpr, dpr);

  preloadAll();

  function frame(now) {
    const t = now / 1000;
    const { state, is_night, wpm } = current;

    ctx.clearRect(0, 0, SIZE, SIZE);

    // Behind the body.
    drawShadow(ctx);
    if (state === "flow") drawGlow(ctx, t);
    if (state === "record") drawFireworks(ctx, t);

    // The crab.
    drawSprite(ctx, state, is_night, t);

    // In front of the body.
    drawFrontEffects(ctx, state, t);
    if (showsWPM(state)) drawWPM(ctx, wpm, t);

    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);

  const { listen } = window.__TAURI__.event;
  listen("pet-update", (event) => {
    const u = event.payload;
    if (u.state !== current.state) {
      stateChangedAt = performance.now() / 1000;
    }
    current = { state: u.state, is_night: u.is_night, wpm: u.wpm };
  });
});
