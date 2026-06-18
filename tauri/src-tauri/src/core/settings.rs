//! User-tunable thresholds for the state machine and metrics engine.
//!
//! Mirrors `PetSettings` from the Swift app. The `Default` impl is the single
//! source of truth for "factory settings"; persistence (the UserDefaults
//! equivalent) is wired up in a later milestone, so for now the engines read a
//! plain in-memory `Settings`.

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
pub struct Settings {
    // Appearance — on-screen scale of the crab (1.0 == base 200pt window).
    pub pet_scale: f64,

    // Idle progression (seconds).
    pub thinking_after: f64,
    pub sleepy_after: f64,
    pub sleeping_after: f64,

    // Flow.
    pub flow_enabled: bool,
    pub flow_threshold: i64, // real WPM
    pub flow_sustain: f64,   // seconds

    // Deleting.
    pub deleting_enabled: bool,
    pub delete_rate_threshold: f64, // 0..1

    // Night (hours of day; start == end disables; start > end wraps midnight).
    pub night_enabled: bool,
    pub night_start_hour: u32,
    pub night_end_hour: u32,

    // Active-typing detection.
    pub active_threshold: f64, // seconds since last key

    // Advanced.
    pub wpm_window: f64,      // seconds
    pub delete_window: f64,   // seconds
    pub record_duration: f64, // seconds
    pub wakeup_duration: f64, // seconds
}

impl Default for Settings {
    /// Factory defaults — must match `PetSettings.Default` in the Swift app.
    fn default() -> Self {
        Self {
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
        }
    }
}
