// Settings window — a grouped slider form mirroring the Swift SettingsView.
// Every edit applies live (update_settings) and is persisted by the backend.

const { invoke } = window.__TAURI__.core;

// Factory defaults — must match Settings::default() in Rust.
const DEFAULTS = {
  pet_scale: 1.0,
  thinking_after: 30.0,
  sleepy_after: 120.0,
  sleeping_after: 300.0,
  flow_enabled: true,
  flow_threshold: 60,
  flow_sustain: 30.0,
  deleting_enabled: true,
  delete_rate_threshold: 0.5,
  night_enabled: true,
  night_start_hour: 0,
  night_end_hour: 5,
  active_threshold: 2.0,
  wpm_window: 10.0,
  delete_window: 20.0,
  record_duration: 3.0,
  wakeup_duration: 2.0,
};

let S = { ...DEFAULTS };

// ---- formatting ----------------------------------------------------------

function durationLabel(v) {
  if (v < 60) return Number.isInteger(v) ? `${v} 秒` : `${v.toFixed(1)} 秒`;
  const m = Math.floor(v / 60);
  const s = Math.floor(v) % 60;
  return s === 0 ? `${m} 分` : `${m} 分 ${s} 秒`;
}
const percentLabel = (v) => `${Math.round(v * 100)}%`;
const wpmLabel = (v) => `${v} WPM`;

function nightSummary() {
  const s = S.night_start_hour, e = S.night_end_hour;
  const p = (h) => String(h).padStart(2, "0");
  if (s === e) return "开始与结束相同，夜间模式不会触发。";
  if (s > e) return `当前：${p(s)}:00 – 次日 ${p(e)}:00（跨午夜）`;
  return `当前：${p(s)}:00 – ${p(e)}:00`;
}

// ---- persistence ---------------------------------------------------------

let saveTimer;
function save() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => invoke("update_settings", { settings: S }), 80);
}

let toastTimer;
function toast(msg) {
  const t = document.getElementById("toast");
  t.textContent = msg;
  t.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.remove("show"), 1600);
}

// ---- tiny DOM helper -----------------------------------------------------

function el(tag, props = {}, children = []) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(props)) {
    if (k === "class") e.className = v;
    else if (k === "html") e.innerHTML = v;
    else if (k.startsWith("on")) e.addEventListener(k.slice(2), v);
    else e.setAttribute(k, v);
  }
  for (const c of [].concat(children)) {
    if (c) e.append(c.nodeType ? c : document.createTextNode(c));
  }
  return e;
}

// Track rows that enable/disable with a parent toggle, and dynamic footers.
let deps = [];
let footers = [];
function refreshDynamic() {
  for (const { row, on } of deps) row.classList.toggle("disabled", !on());
  for (const { node, text } of footers) node.textContent = text();
}

// ---- row builders --------------------------------------------------------

function sliderRow({ key, label, min, max, step, fmt, clamp }) {
  const value = el("span", { class: "value" }, fmt(S[key]));
  const input = el("input", { type: "range", min, max, step });
  input.value = S[key];
  const isInt = Number.isInteger(step) && Number.isInteger(DEFAULTS[key]);
  input.addEventListener("input", () => {
    let v = isInt ? parseInt(input.value, 10) : parseFloat(input.value);
    if (clamp) {
      v = clamp(v);
      input.value = v;
    }
    S[key] = v;
    value.textContent = fmt(v);
    save();
    refreshDynamic();
  });
  return el("div", { class: "row" }, [
    el("div", { class: "row-head" }, [el("label", {}, label), value]),
    input,
  ]);
}

function toggleRow({ key, label, onToggle, special }) {
  const input = el("input", { type: "checkbox" });
  input.checked = special ? false : S[key];
  if (special) special(input); // e.g. autostart loads its own state
  input.addEventListener("change", () => {
    if (special) {
      onToggle(input.checked);
    } else {
      S[key] = input.checked;
      save();
    }
    refreshDynamic();
  });
  const sw = el("label", { class: "switch" }, [
    input,
    el("span", { class: "slot" }),
    el("span", { class: "knob" }),
  ]);
  return el("div", { class: "row" }, [
    el("div", { class: "row-head" }, [el("label", {}, label), sw]),
  ]);
}

function hourRow({ key, label }) {
  const sel = el("select");
  for (let h = 0; h < 24; h++) {
    const o = el("option", { value: h }, `${String(h).padStart(2, "0")}:00`);
    if (h === S[key]) o.selected = true;
    sel.append(o);
  }
  sel.addEventListener("change", () => {
    S[key] = parseInt(sel.value, 10);
    save();
    refreshDynamic();
  });
  return el("div", { class: "row" }, [
    el("div", { class: "row-head" }, [el("label", {}, label), sel]),
  ]);
}

function buttonRow(label, cls, onClick) {
  return el("div", { class: "btn-row" }, [
    el("button", { class: `link ${cls}`, onclick: onClick }, label),
  ]);
}

function section(title, rows, footerText) {
  const body = el("div", { class: "section-body" }, rows);
  const parts = [el("div", { class: "section-title" }, title), body];
  if (footerText) {
    const f = el("div", { class: "section-footer" }, footerText());
    footers.push({ node: f, text: footerText });
    parts.push(f);
  }
  return el("div", { class: "section" }, parts);
}

function dep(row, on) {
  deps.push({ row, on });
  return row;
}

// ---- render --------------------------------------------------------------

function render() {
  deps = [];
  footers = [];
  const form = document.getElementById("form");
  form.innerHTML = "";

  // 通用
  form.append(
    section("通用", [
      toggleRow({
        label: "登录时启动",
        special: async (input) => {
          input.checked = await invoke("get_autostart");
        },
        onToggle: async (v) => {
          await invoke("set_autostart", { enabled: v });
          toast(v ? "已开启登录时启动" : "已关闭登录时启动");
        },
      }),
    ])
  );

  // 外观
  form.append(
    section("外观", [
      sliderRow({
        key: "pet_scale", label: "桌面螃蟹大小",
        min: 0.6, max: 2.0, step: 0.05, fmt: percentLabel,
      }),
    ])
  );

  // 空闲节奏 (with clamping: thinking < sleepy < sleeping)
  form.append(
    section(
      "空闲节奏",
      [
        sliderRow({
          key: "thinking_after", label: "发呆 → 思考", min: 5, max: 300, step: 1,
          fmt: durationLabel, clamp: (v) => Math.min(v, S.sleepy_after - 1),
        }),
        sliderRow({
          key: "sleepy_after", label: "思考 → 犯困", min: 10, max: 900, step: 1,
          fmt: durationLabel,
          clamp: (v) => Math.min(Math.max(v, S.thinking_after + 1), S.sleeping_after - 1),
        }),
        sliderRow({
          key: "sleeping_after", label: "犯困 → 睡着", min: 20, max: 1800, step: 1,
          fmt: durationLabel, clamp: (v) => Math.max(v, S.sleepy_after + 1),
        }),
      ],
      () => "三个阈值会自动保持递增顺序：思考 < 犯困 < 睡着。"
    )
  );

  // 心流
  const flowOn = () => S.flow_enabled;
  form.append(
    section("心流", [
      toggleRow({ key: "flow_enabled", label: "启用心流状态" }),
      dep(sliderRow({
        key: "flow_threshold", label: "WPM 阈值", min: 20, max: 150, step: 5, fmt: wpmLabel,
      }), flowOn),
      dep(sliderRow({
        key: "flow_sustain", label: "持续时间", min: 5, max: 120, step: 1, fmt: durationLabel,
      }), flowOn),
    ])
  );

  // 纠结
  const delOn = () => S.deleting_enabled;
  form.append(
    section("纠结（高删除率）", [
      toggleRow({ key: "deleting_enabled", label: "启用纠结状态" }),
      dep(sliderRow({
        key: "delete_rate_threshold", label: "删除率阈值",
        min: 0.1, max: 0.9, step: 0.05, fmt: percentLabel,
      }), delOn),
    ])
  );

  // 夜间
  const nightOn = () => S.night_enabled;
  form.append(
    section(
      "夜间时段",
      [
        toggleRow({ key: "night_enabled", label: "启用夜间模式（穿睡衣）" }),
        dep(hourRow({ key: "night_start_hour", label: "开始时间" }), nightOn),
        dep(hourRow({ key: "night_end_hour", label: "结束时间" }), nightOn),
      ],
      nightSummary
    )
  );

  // 高级 (disclosure)
  const advRows = [
    sliderRow({ key: "active_threshold", label: "活跃判定（距上次按键）", min: 0.5, max: 5, step: 0.5, fmt: durationLabel }),
    sliderRow({ key: "wpm_window", label: "WPM 采样窗口", min: 3, max: 30, step: 1, fmt: durationLabel }),
    sliderRow({ key: "delete_window", label: "删除率采样窗口", min: 5, max: 60, step: 1, fmt: durationLabel }),
    sliderRow({ key: "record_duration", label: "破纪录庆祝时长", min: 1, max: 10, step: 1, fmt: durationLabel }),
    sliderRow({ key: "wakeup_duration", label: "惊醒动画时长", min: 1, max: 5, step: 0.5, fmt: durationLabel }),
  ];
  const details = el("details", {}, [
    el("summary", { class: "disclosure-toggle row" }, "高级参数"),
    el("div", {}, advRows),
  ]);
  form.append(
    section("", [details], () => "一般无需改动；除非你想微调指标灵敏度或动画时长。")
  );

  // 数据
  form.append(
    section(
      "数据",
      [
        buttonRow("导出数据…", "", async () => {
          const json = await invoke("export_data");
          try {
            await navigator.clipboard.writeText(json);
            toast("已复制到剪贴板（仅聚合计数）");
          } catch {
            toast("复制失败，请重试");
          }
        }),
        buttonRow("清除所有数据…", "danger", async () => {
          if (!confirm("将永久删除全部击键统计、经验/等级和峰值 WPM 记录。此操作无法撤销。")) return;
          await invoke("erase_all");
          toast("已清除所有数据");
        }),
      ],
      () => "导出为 JSON（仅含聚合的逐小时击键数、经验与记录，绝不含输入内容）。"
    )
  );

  // 重置
  form.append(
    section("", [
      buttonRow("恢复默认设置", "danger", async () => {
        S = { ...DEFAULTS };
        await invoke("update_settings", { settings: S });
        render();
        toast("已恢复默认设置");
      }),
    ])
  );

  refreshDynamic();
}

window.addEventListener("DOMContentLoaded", async () => {
  S = { ...DEFAULTS, ...(await invoke("get_settings")) };
  render();
});
