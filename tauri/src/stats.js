// Statistics window — mirrors the Swift StatsPanel: live header, summary cards,
// a GitHub-style monthly calendar with drill-down, and an hourly breakdown.

const { invoke } = window.__TAURI__.core;
const { listen } = window.__TAURI__.event;

const pad = (n) => String(n).padStart(2, "0");
const dayStr = (y, m, d) => `${y}-${pad(m)}-${pad(d)}`;
const WEEKDAYS = ["日", "一", "二", "三", "四", "五", "六"];

const today = (() => {
  const n = new Date();
  return dayStr(n.getFullYear(), n.getMonth() + 1, n.getDate());
})();
const nowYear = new Date().getFullYear();
const nowMonth = new Date().getMonth() + 1;

let dYear = nowYear;
let dMonth = nowMonth;
let selectedDay = null; // null = today
let hourly = new Array(24).fill(0);
let daily = {};

const effectiveDay = () => selectedDay || today;
const isCurrentMonth = () => dYear === nowYear && dMonth === nowMonth;

// StatsPanel green ramp: empty → faint; else 0.25..1.0 intensity.
function cellColor(count, max) {
  if (count <= 0) return "var(--cell-empty)";
  const intensity = 0.25 + 0.75 * (count / Math.max(1, max));
  return `rgba(46, 184, 102, ${intensity})`;
}

// ---- header (live from pet-update) --------------------------------------

function applyHeader(u) {
  document.getElementById("emoji").textContent = u.emoji;
  document.getElementById("levelState").textContent = `Lv.${u.level} · ${u.display_name}`;
  document.getElementById("xpfill").style.width = `${Math.round(u.level_progress * 100)}%`;
  document.getElementById("xptext").textContent =
    `还需 ${u.xp_to_next} XP 到 Lv.${u.level + 1}`;
  document.getElementById("today").textContent = u.today_keystrokes;
  document.getElementById("peak").textContent = u.peak_wpm;
}

// ---- monthly calendar ----------------------------------------------------

function renderCalendar() {
  document.getElementById("month").textContent = `${dYear} 年 ${dMonth} 月`;
  document.getElementById("next").disabled = isCurrentMonth();

  const first = new Date(dYear, dMonth - 1, 1);
  const leading = first.getDay(); // 0 = Sunday
  const daysInMonth = new Date(dYear, dMonth, 0).getDate();
  const weekCount = Math.ceil((leading + daysInMonth) / 7);

  // grid[week][row] = day | null
  const grid = Array.from({ length: weekCount }, () => new Array(7).fill(null));
  for (let day = 1; day <= daysInMonth; day++) {
    const pos = leading + (day - 1);
    grid[Math.floor(pos / 7)][pos % 7] = day;
  }

  const maxDaily = Math.max(1, ...Object.values(daily), 1);
  const grid_el = document.getElementById("calGrid");
  grid_el.innerHTML = "";

  // Weekday label column.
  const labels = document.createElement("div");
  labels.className = "wk labels";
  for (const w of WEEKDAYS) {
    const s = document.createElement("div");
    s.className = "wlabel";
    s.textContent = w;
    labels.append(s);
  }
  grid_el.append(labels);

  // Week columns.
  for (const week of grid) {
    const col = document.createElement("div");
    col.className = "wk";
    for (const day of week) {
      const cell = document.createElement("div");
      if (day === null) {
        cell.className = "cell empty-slot";
      } else {
        const ds = dayStr(dYear, dMonth, day);
        const count = daily[day] || 0;
        cell.className = "cell";
        cell.style.background = cellColor(count, maxDaily);
        cell.textContent = day;
        cell.style.color = count > 0 ? "rgba(255,255,255,0.9)" : "var(--muted)";
        if (ds === effectiveDay()) cell.style.border = "2px solid var(--green-strong)";
        else if (ds === today) cell.style.border = "1px solid var(--green-soft)";
        else cell.style.border = "1px solid var(--border-faint)";
        cell.title = `${dYear} 年 ${dMonth} 月 ${day} 日 — ${count} 击键`;
        cell.addEventListener("click", () => {
          selectedDay = ds;
          reload();
        });
      }
      col.append(cell);
    }
    grid_el.append(col);
  }
}

// ---- hourly heatmap ------------------------------------------------------

function renderHourly() {
  const eff = effectiveDay();
  const max = Math.max(1, ...hourly);

  // Title.
  let title = "今日活动分布（按小时）";
  if (eff !== today) {
    const [, m, d] = eff.split("-");
    title = `${Number(m)} 月 ${Number(d)} 日活动分布（按小时）`;
  }
  document.getElementById("hourlyTitle").textContent = title;

  // Active hours card + peak label.
  const active = hourly.filter((c) => c > 0).length;
  document.getElementById("active").textContent = active;
  let peakHour = -1, peakVal = 0;
  hourly.forEach((c, h) => {
    if (c > peakVal) { peakVal = c; peakHour = h; }
  });
  document.getElementById("peak-hour").textContent =
    peakVal > 0 ? `最活跃：${pad(peakHour)}:00` : "";

  const el = document.getElementById("hours");
  el.innerHTML = "";
  hourly.forEach((count, hour) => {
    const c = document.createElement("div");
    c.className = "hcell";
    c.style.background = cellColor(count, max);
    c.title = `${pad(hour)}:00 — ${count} 击键`;
    el.append(c);
  });
}

// ---- data ----------------------------------------------------------------

async function reload() {
  const month = `${dYear}-${pad(dMonth)}`;
  hourly = await invoke("hourly_counts", { day: effectiveDay() });
  daily = await invoke("daily_counts", { month });
  renderCalendar();
  renderHourly();
}

function changeMonth(delta) {
  dMonth += delta;
  if (dMonth < 1) { dMonth = 12; dYear--; }
  else if (dMonth > 12) { dMonth = 1; dYear++; }
  reload();
}

window.addEventListener("DOMContentLoaded", () => {
  document.getElementById("prev").addEventListener("click", () => changeMonth(-1));
  document.getElementById("next").addEventListener("click", () => changeMonth(1));

  reload();
  setInterval(reload, 5000);

  // Live header from the runtime's broadcast.
  listen("pet-update", (e) => applyHeader(e.payload));
});
