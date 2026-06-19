//! Tauri commands backing the stats and settings windows.

use std::sync::Arc;

use chrono::Local;
use serde::Serialize;
use tauri::State;

use crate::core::stats_store::{day_string, month_string};
use crate::core::Settings;
use crate::runtime::AppState;

/// Merge any unflushed keystroke buckets into the persistent store so queries
/// reflect the current session.
fn flush_pending(state: &AppState) {
    let drained: Vec<((String, u32), i64)> = { state.pending.lock().unwrap().drain().collect() };
    if drained.is_empty() {
        return;
    }
    let mut stats = state.stats.lock().unwrap();
    for ((day, hour), count) in drained {
        stats.add(count, &day, hour);
    }
    stats.save();
}

#[derive(Serialize)]
pub struct Summary {
    level: i64,
    level_progress: f64,
    xp_to_next: i64,
    total_xp: i64,
    today_keystrokes: i64,
    current_wpm: i64,
    peak_wpm: i64,
    today: String,
    month: String,
}

#[tauri::command]
pub fn get_summary(state: State<'_, Arc<AppState>>) -> Summary {
    let rt = state.runtime.lock().unwrap();
    let m = rt.metrics.metrics.clone();
    let now = Local::now();
    Summary {
        level: rt.xp.level(),
        level_progress: rt.xp.level_progress(),
        xp_to_next: rt.xp.xp_to_next_level(),
        total_xp: rt.xp.total_xp(),
        today_keystrokes: m.today_keystrokes,
        current_wpm: m.wpm,
        peak_wpm: m.peak_wpm,
        today: day_string(now),
        month: month_string(now),
    }
}

/// Keystroke count per hour (0..=23) for a `"yyyy-MM-dd"` day.
#[tauri::command]
pub fn hourly_counts(state: State<'_, Arc<AppState>>, day: String) -> Vec<i64> {
    flush_pending(&state);
    let stats = state.stats.lock().unwrap();
    let map = stats.hourly_counts(&day);
    (0..24).map(|h| *map.get(&h).unwrap_or(&0)).collect()
}

/// Keystroke count per day-of-month for a `"yyyy-MM"` month.
#[tauri::command]
pub fn daily_counts(
    state: State<'_, Arc<AppState>>,
    month: String,
) -> std::collections::BTreeMap<u32, i64> {
    flush_pending(&state);
    let stats = state.stats.lock().unwrap();
    stats.daily_counts(&month)
}

#[tauri::command]
pub fn get_settings(state: State<'_, Arc<AppState>>) -> Settings {
    state.settings.lock().unwrap().clone()
}

#[tauri::command]
pub fn update_settings(state: State<'_, Arc<AppState>>, settings: Settings) {
    *state.settings.lock().unwrap() = settings;
    // Engines pick up the new settings on the next tick (set_settings).
    state.save_settings_now();
}

#[tauri::command]
pub fn get_autostart(app: tauri::AppHandle) -> bool {
    use tauri_plugin_autostart::ManagerExt;
    app.autolaunch().is_enabled().unwrap_or(false)
}

#[tauri::command]
pub fn set_autostart(app: tauri::AppHandle, enabled: bool) {
    use tauri_plugin_autostart::ManagerExt;
    let manager = app.autolaunch();
    let _ = if enabled {
        manager.enable()
    } else {
        manager.disable()
    };
}

/// Export every aggregate count as a JSON string (no characters — privacy).
#[tauri::command]
pub fn export_data(state: State<'_, Arc<AppState>>) -> String {
    flush_pending(&state);
    let rows = {
        let stats = state.stats.lock().unwrap();
        stats.all_hourly()
    };
    let hourly: Vec<_> = rows
        .into_iter()
        .map(|(day, hour, count)| {
            serde_json::json!({ "day": day, "hour": hour, "count": count })
        })
        .collect();
    let summary = get_summary(state);
    serde_json::to_string_pretty(&serde_json::json!({
        "exported_at": Local::now().to_rfc3339(),
        "level": summary.level,
        "total_xp": summary.total_xp,
        "peak_wpm": summary.peak_wpm,
        "hourly": hourly,
    }))
    .unwrap_or_else(|_| "{}".to_string())
}

/// Erase all stored keystroke buckets and reset XP / peak WPM.
#[tauri::command]
pub fn erase_all(state: State<'_, Arc<AppState>>) {
    state.pending.lock().unwrap().clear();
    state.stats.lock().unwrap().erase_all();
    {
        let mut rt = state.runtime.lock().unwrap();
        rt.xp.reset();
        rt.metrics.reset_all_counters();
    }
    state.save_profile_now();
}
