//! On-disk persistence for settings and the player profile (XP / peak WPM /
//! today's count). Stats buckets live separately in `StatsStore`.

use std::path::PathBuf;

use serde::{Deserialize, Serialize};

use crate::core::Settings;

/// Load settings from `path`, falling back to factory defaults.
pub fn load_settings(path: &PathBuf) -> Settings {
    std::fs::read_to_string(path)
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_default()
}

/// Persist settings as pretty JSON.
pub fn save_settings(path: &PathBuf, settings: &Settings) {
    write_json(path, settings);
}

/// Durable per-player progress, restored on launch.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct Profile {
    pub total_xp: i64,
    pub peak_wpm: i64,
    pub today_keystrokes: i64,
    /// "yyyy-MM-dd" the today-counter belongs to; cleared on a new day.
    pub today_date: String,
}

pub fn load_profile(path: &PathBuf) -> Profile {
    std::fs::read_to_string(path)
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_default()
}

pub fn save_profile(path: &PathBuf, profile: &Profile) {
    write_json(path, profile);
}

fn write_json<T: Serialize>(path: &PathBuf, value: &T) {
    if let Some(parent) = path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    if let Ok(json) = serde_json::to_string_pretty(value) {
        let _ = std::fs::write(path, json);
    }
}
