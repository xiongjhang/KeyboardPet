const { invoke } = window.__TAURI__.core;

function intensity(count, max) {
  if (count <= 0 || max <= 0) return 0;
  // 1..4 buckets, GitHub-style.
  return Math.min(4, Math.ceil((count / max) * 4));
}

function renderHours(counts) {
  const el = document.querySelector("#hours");
  el.innerHTML = "";
  const max = Math.max(1, ...counts);
  counts.forEach((c, hour) => {
    const cell = document.createElement("div");
    cell.className = `cell lvl${intensity(c, max)}`;
    cell.title = `${hour}:00 — ${c} 次`;
    el.appendChild(cell);
  });
}

function renderDays(map, month) {
  const el = document.querySelector("#days");
  el.innerHTML = "";
  const [y, m] = month.split("-").map(Number);
  const daysInMonth = new Date(y, m, 0).getDate();
  const values = Object.values(map);
  const max = Math.max(1, ...(values.length ? values : [0]));
  for (let d = 1; d <= daysInMonth; d++) {
    const c = map[d] || 0;
    const cell = document.createElement("div");
    cell.className = `cell lvl${intensity(c, max)}`;
    cell.title = `${month}-${String(d).padStart(2, "0")} — ${c} 次`;
    el.appendChild(cell);
  }
}

async function refresh() {
  const s = await invoke("get_summary");
  document.querySelector("#level").textContent = s.level;
  document.querySelector("#today").textContent = s.today_keystrokes;
  document.querySelector("#wpm").textContent = s.current_wpm;
  document.querySelector("#peak").textContent = s.peak_wpm;
  document.querySelector("#xpfill").style.width = `${Math.round(s.level_progress * 100)}%`;
  document.querySelector("#xptext").textContent = `距离下一级还需 ${s.xp_to_next} XP（总 ${s.total_xp}）`;
  document.querySelector("#month-title").textContent = `本月活跃（${s.month}）`;

  const hours = await invoke("hourly_counts", { day: s.today });
  renderHours(hours);
  const days = await invoke("daily_counts", { month: s.month });
  renderDays(days, s.month);
}

window.addEventListener("DOMContentLoaded", () => {
  refresh();
  // Live-ish: refresh every few seconds while the panel is open.
  setInterval(refresh, 3000);
});
