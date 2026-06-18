// Renders the pet from live `pet-update` events emitted by the Rust runtime.
// Each event carries the resolved state, night flag, and metrics; the frontend
// only animates frames and shows the WPM readout — all logic lives in core.

const FRAME_MS = 450;
const ASSET_BASE = "/assets/clawd";

// All states ship 2 frames except `wakeup` (a single startle frame). Night
// variants mirror the day set with a `night_` prefix.
function framesFor(state, night) {
  const prefix = night ? "night_" : "";
  const stem = `${ASSET_BASE}/${prefix}${state}`;
  if (state === "wakeup") return [`${stem}_0.png`];
  return [`${stem}_0.png`, `${stem}_1.png`];
}

// Every sprite path we might show — preloaded once so frame swaps never flicker.
const ALL_STATES = [
  "idle", "typing", "flow", "deleting", "thinking",
  "sleepy", "sleeping", "wakeup", "record",
];
function preloadAll() {
  for (const state of ALL_STATES) {
    for (const night of [false, true]) {
      for (const src of framesFor(state, night)) {
        const img = new Image();
        img.src = src;
      }
    }
  }
}

window.addEventListener("DOMContentLoaded", async () => {
  const petEl = document.querySelector("#pet");
  const spriteEl = document.querySelector("#sprite");
  const wpmEl = document.querySelector("#wpm");
  const wpmValueEl = document.querySelector("#wpm-value");

  preloadAll();

  let frames = framesFor("idle", false);
  let frameIndex = 0;
  let currentKey = "idle|day"; // state + night, to detect changes

  spriteEl.src = frames[0];

  // Frame loop — independent of event cadence so animation stays smooth.
  setInterval(() => {
    frameIndex = (frameIndex + 1) % frames.length;
    spriteEl.src = frames[frameIndex];
  }, FRAME_MS);

  function applyUpdate(u) {
    const key = `${u.state}|${u.is_night ? "night" : "day"}`;
    if (key !== currentKey) {
      currentKey = key;
      frames = framesFor(u.state, u.is_night);
      frameIndex = 0;
      spriteEl.src = frames[0];
    }

    // WPM readout: visible while actively typing.
    if (u.wpm > 0) {
      wpmValueEl.textContent = u.wpm;
      wpmEl.classList.remove("hidden");
      wpmEl.classList.toggle("flow", u.state === "flow");
    } else {
      wpmEl.classList.add("hidden");
    }

    // Celebratory bounce while breaking a record.
    petEl.classList.toggle("celebrate", u.state === "record");
  }

  // Subscribe to the Rust runtime's updates.
  const { listen } = window.__TAURI__.event;
  await listen("pet-update", (event) => applyUpdate(event.payload));
});
