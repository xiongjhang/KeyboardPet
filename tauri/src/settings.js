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

const BOOL_FIELDS = ["flow_enabled", "deleting_enabled", "night_enabled"];
// Integer fields must serialize without a decimal (Rust i64 / u32).
const INT_FIELDS = ["flow_threshold", "night_start_hour", "night_end_hour"];

function fieldIds() {
  return Object.keys(DEFAULTS);
}

function populate(settings) {
  for (const id of fieldIds()) {
    const el = document.getElementById(id);
    if (!el) continue;
    if (BOOL_FIELDS.includes(id)) el.checked = !!settings[id];
    else el.value = settings[id];
  }
}

function collect() {
  const out = {};
  for (const id of fieldIds()) {
    const el = document.getElementById(id);
    if (BOOL_FIELDS.includes(id)) out[id] = el.checked;
    else if (INT_FIELDS.includes(id)) out[id] = parseInt(el.value, 10);
    else out[id] = parseFloat(el.value);
  }
  return out;
}

async function save() {
  await invoke("update_settings", { settings: collect() });
}

let toastTimer;
function toast(msg) {
  const t = document.getElementById("toast");
  t.textContent = msg;
  t.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.remove("show"), 1600);
}

window.addEventListener("DOMContentLoaded", async () => {
  populate(await invoke("get_settings"));

  // Persist on any edit.
  for (const id of fieldIds()) {
    const el = document.getElementById(id);
    if (el) el.addEventListener("change", save);
  }

  // Launch-at-login is an OS toggle, separate from the engine settings.
  const autostartEl = document.getElementById("autostart");
  autostartEl.checked = await invoke("get_autostart");
  autostartEl.addEventListener("change", async () => {
    await invoke("set_autostart", { enabled: autostartEl.checked });
    toast(autostartEl.checked ? "已开启开机自启" : "已关闭开机自启");
  });

  document.getElementById("reset").addEventListener("click", async () => {
    populate(DEFAULTS);
    await save();
    toast("已恢复默认设置");
  });

  document.getElementById("export").addEventListener("click", async () => {
    const json = await invoke("export_data");
    try {
      await navigator.clipboard.writeText(json);
      toast("已复制到剪贴板（仅聚合计数）");
    } catch {
      toast("复制失败，请重试");
    }
  });

  document.getElementById("erase").addEventListener("click", async () => {
    if (!confirm("确定要清除全部按键统计、等级与记录吗？此操作不可撤销。")) return;
    await invoke("erase_all");
    toast("已清除全部数据");
  });
});
