//! Wires the keyboard hook into the core engines, persists state, and pushes
//! live updates to the frontend.
//!
//! Shared state lives in `AppState`, managed by Tauri so commands (stats /
//! settings windows) can read it too. This is the cross-platform analogue of
//! the Swift `PetController`.

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use chrono::{Local, Utc};
use serde::Serialize;
use tauri::menu::MenuItem;
use tauri::{AppHandle, Emitter, Manager, Wry};

use crate::core::stats_store::{day_string, hour_of};
use crate::core::{ExperienceManager, MetricsEngine, PetStateMachine, Settings, StatsStore};
use crate::persist::{self, Profile};
use crate::platform;

/// Flush pending keystroke counts + profile to disk every 60s (120 ticks of
/// 500ms), matching the Swift batching budget.
const FLUSH_EVERY_TICKS: u32 = 120;

/// Owns the live engines.
pub struct PetRuntime {
    pub metrics: MetricsEngine,
    pub machine: PetStateMachine,
    pub xp: ExperienceManager,
}

impl PetRuntime {
    fn with_seed(settings: &Settings, total_xp: i64, peak_wpm: i64, today: i64) -> Self {
        Self {
            metrics: MetricsEngine::new(settings.clone(), peak_wpm, today),
            machine: PetStateMachine::new(settings.clone()),
            xp: ExperienceManager::new(total_xp),
        }
    }
}

/// Shared application state, managed by Tauri.
pub struct AppState {
    pub runtime: Mutex<PetRuntime>,
    pub stats: Mutex<StatsStore>,
    pub settings: Mutex<Settings>,
    /// Unflushed per-(day, hour) keystroke counts awaiting a batched write.
    pub pending: Mutex<HashMap<(String, u32), i64>>,
    pub settings_path: Option<PathBuf>,
    pub profile_path: Option<PathBuf>,
}

impl AppState {
    /// Persist the current settings to disk.
    pub fn save_settings_now(&self) {
        if let Some(path) = &self.settings_path {
            persist::save_settings(path, &self.settings.lock().unwrap());
        }
    }

    /// Persist the player profile (XP / peak / today's count) to disk.
    pub fn save_profile_now(&self) {
        if let Some(path) = &self.profile_path {
            let rt = self.runtime.lock().unwrap();
            let m = &rt.metrics.metrics;
            let profile = Profile {
                total_xp: rt.xp.total_xp(),
                peak_wpm: m.peak_wpm,
                today_keystrokes: m.today_keystrokes,
                today_date: day_string(Local::now()),
            };
            persist::save_profile(path, &profile);
        }
    }
}

/// Live tray-menu summary lines (display-only), refreshed each tick to mirror
/// the Swift menu-bar dropdown.
pub struct TraySummary {
    pub status: MenuItem<Wry>,
    pub level: MenuItem<Wry>,
    pub today: MenuItem<Wry>,
    pub wpm: MenuItem<Wry>,
    pub peak: MenuItem<Wry>,
}

/// Snapshot pushed to the pet window on every tick.
#[derive(Serialize, Clone)]
struct PetUpdate {
    state: String,
    display_name: String,
    emoji: String,
    is_night: bool,
    wpm: i64,
    peak_wpm: i64,
    today_keystrokes: i64,
    delete_rate: f64,
    level: i64,
    level_progress: f64,
    xp_to_next: i64,
}

/// Start keyboard monitoring, persistence, and the state ticker. Call once from
/// `setup`. Returns the managed state so the caller can register it.
pub fn launch(app: &AppHandle, tray: TraySummary) -> Arc<AppState> {
    // macOS: the listener needs Accessibility permission (prompts on first run).
    #[cfg(target_os = "macos")]
    {
        let trusted =
            macos_accessibility_client::accessibility::application_is_trusted_with_prompt();
        if !trusted {
            eprintln!(
                "[keyboard] Accessibility not granted yet — enable KeyboardPet under \
                 System Settings ▸ Privacy & Security ▸ Accessibility, then relaunch."
            );
        }
    }

    let data_dir = app.path().app_data_dir().ok();
    let settings_path = data_dir.as_ref().map(|d| d.join("settings.json"));
    let profile_path = data_dir.as_ref().map(|d| d.join("profile.json"));
    let stats_path = data_dir.as_ref().map(|d| d.join("stats.json"));

    let settings = settings_path
        .as_ref()
        .map(persist::load_settings)
        .unwrap_or_default();
    let profile = profile_path
        .as_ref()
        .map(persist::load_profile)
        .unwrap_or_default();

    // Restore today's counter only if it belongs to the current day.
    let today = day_string(Local::now());
    let seeded_today = if profile.today_date == today {
        profile.today_keystrokes
    } else {
        0
    };

    let state = Arc::new(AppState {
        runtime: Mutex::new(PetRuntime::with_seed(
            &settings,
            profile.total_xp,
            profile.peak_wpm,
            seeded_today,
        )),
        stats: Mutex::new(StatsStore::load(stats_path)),
        settings: Mutex::new(settings),
        pending: Mutex::new(HashMap::new()),
        settings_path,
        profile_path,
    });

    // Keyboard → metrics + XP, and record the bucket for batched persistence.
    let kb_state = state.clone();
    platform::keyboard::start_listener(move |event| {
        let now = event.timestamp;
        {
            let mut rt = kb_state.runtime.lock().unwrap();
            let broke_record = rt.metrics.ingest(event);
            rt.xp.award(1);
            if broke_record.is_some() {
                rt.machine.trigger_record(now);
            }
        }
        let local = now.with_timezone(&Local);
        let mut pending = kb_state.pending.lock().unwrap();
        *pending.entry((day_string(local), hour_of(local))).or_insert(0) += 1;
    });

    // 0.5s ticker → live settings, recompute, evaluate, persist, emit.
    let tick_state = state.clone();
    let handle = app.clone();
    std::thread::spawn(move || {
        let mut ticks: u32 = 0;
        let mut last_day = day_string(Local::now());

        loop {
            std::thread::sleep(Duration::from_millis(500));
            ticks = ticks.wrapping_add(1);
            let now = Utc::now();
            let today = day_string(Local::now());

            let update = {
                let settings = tick_state.settings.lock().unwrap().clone();
                let mut rt = tick_state.runtime.lock().unwrap();

                // Apply any live settings edits to the engines.
                rt.metrics.set_settings(settings.clone());
                rt.machine.set_settings(settings.clone());

                // Day rollover resets the today-counter.
                if today != last_day {
                    rt.metrics.reset_daily();
                    last_day = today.clone();
                }

                if rt.metrics.tick(now).is_some() {
                    rt.machine.trigger_record(now);
                }
                let m = rt.metrics.metrics.clone();
                let state = rt.machine.evaluate(&m, now);
                let is_night = PetStateMachine::is_night(Local::now(), &settings);
                PetUpdate {
                    state: state.as_str().to_string(),
                    display_name: state.display_name().to_string(),
                    emoji: state.emoji().to_string(),
                    is_night,
                    wpm: m.wpm,
                    peak_wpm: m.peak_wpm,
                    today_keystrokes: m.today_keystrokes,
                    delete_rate: m.delete_rate,
                    level: rt.xp.level(),
                    level_progress: rt.xp.level_progress(),
                    xp_to_next: rt.xp.xp_to_next_level(),
                }
            };

            // Batched flush of keystroke buckets + profile to disk.
            if ticks % FLUSH_EVERY_TICKS == 0 {
                let drained: Vec<((String, u32), i64)> = {
                    let mut pending = tick_state.pending.lock().unwrap();
                    pending.drain().collect()
                };
                if !drained.is_empty() {
                    let mut stats = tick_state.stats.lock().unwrap();
                    for ((day, hour), count) in drained {
                        stats.add(count, &day, hour);
                    }
                    stats.save();
                }
                tick_state.save_profile_now();
            }

            // Refresh the tray summary lines (display-only).
            let night = if update.is_night { " · 🌙" } else { "" };
            let _ = tray.status.set_text(format!(
                "KeyboardPet {} {}{}",
                update.emoji, update.display_name, night
            ));
            let _ = tray
                .level
                .set_text(format!("Lv.{} · 还需 {} XP 升级", update.level, update.xp_to_next));
            let _ = tray.today.set_text(format!("今日击键：{}", update.today_keystrokes));
            let _ = tray.wpm.set_text(format!("当前 WPM：{}", update.wpm));
            let _ = tray.peak.set_text(format!("峰值 WPM：{}", update.peak_wpm));

            let _ = handle.emit("pet-update", update);
        }
    });

    state
}
