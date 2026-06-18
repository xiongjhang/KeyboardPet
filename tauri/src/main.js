// P0: show the idle crab with a simple 2-frame loop.
// Later milestones drive the frames/state from real keyboard metrics (the Rust core).

const FRAME_MS = 450;
const idleFrames = ["/assets/clawd/idle_0.png", "/assets/clawd/idle_1.png"];

window.addEventListener("DOMContentLoaded", () => {
  const sprite = document.querySelector("#sprite");
  let frame = 0;

  // Preload so frame swaps don't flicker.
  idleFrames.forEach((src) => {
    const img = new Image();
    img.src = src;
  });

  sprite.src = idleFrames[0];
  setInterval(() => {
    frame = (frame + 1) % idleFrames.length;
    sprite.src = idleFrames[frame];
  }, FRAME_MS);
});
