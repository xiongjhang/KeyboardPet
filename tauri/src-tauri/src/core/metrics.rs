//! Computes real-time keyboard metrics from a stream of `KeyEvent`s.
//!
//! Ported from `MetricsEngine`. Only derived numbers are kept — never the
//! events' semantic content. The runtime drives this with a 0.5s `tick` so idle
//! time / WPM decay even when no new keys arrive.

use crate::core::{KeyEvent, Settings};
use chrono::{DateTime, Utc};

/// Standard typing-test convention: one "word" == 5 characters/keystrokes.
const CHARS_PER_WORD: f64 = 5.0;
/// Idle gap that ends a continuous-coding session (seconds).
const SESSION_GAP: f64 = 60.0;

/// Seconds between two instants, as a fractional value (matches Swift's
/// `Date.timeIntervalSince`).
pub(crate) fn secs_between(a: DateTime<Utc>, b: DateTime<Utc>) -> f64 {
    (a - b).num_milliseconds() as f64 / 1000.0
}

/// A point-in-time snapshot of the live keyboard metrics.
#[derive(Debug, Clone)]
pub struct Metrics {
    pub wpm: i64,
    pub delete_rate: f64, // 0.0 ..= 1.0 over the recent window
    pub idle_seconds: f64, // seconds since the last keystroke
    pub continuous_coding_seconds: f64,
    pub today_keystrokes: i64,
    pub peak_wpm: i64,
    /// When WPM first rose above the flow threshold (and has stayed there),
    /// or `None` if currently below.
    pub flow_since: Option<DateTime<Utc>>,
}

impl Default for Metrics {
    fn default() -> Self {
        Self {
            wpm: 0,
            delete_rate: 0.0,
            idle_seconds: 0.0,
            continuous_coding_seconds: 0.0,
            today_keystrokes: 0,
            peak_wpm: 0,
            flow_since: None,
        }
    }
}

pub struct MetricsEngine {
    pub metrics: Metrics,
    settings: Settings,

    keystroke_times: Vec<DateTime<Utc>>, // within wpm_window
    recent_events: Vec<(DateTime<Utc>, bool)>, // within delete_window
    last_key_time: Option<DateTime<Utc>>,
    session_start: Option<DateTime<Utc>>,
}

impl MetricsEngine {
    pub fn new(settings: Settings, initial_peak_wpm: i64, initial_today_keystrokes: i64) -> Self {
        let mut metrics = Metrics::default();
        metrics.peak_wpm = initial_peak_wpm;
        metrics.today_keystrokes = initial_today_keystrokes;
        Self {
            metrics,
            settings,
            keystroke_times: Vec::new(),
            recent_events: Vec::new(),
            last_key_time: None,
            session_start: None,
        }
    }

    /// Ingest a new keyboard event. Returns `Some(wpm)` when this event broke a
    /// pre-existing personal record (matching the Swift `onNewRecord` callback).
    pub fn ingest(&mut self, event: KeyEvent) -> Option<i64> {
        let now = event.timestamp;

        // Continuous-coding session bookkeeping.
        let gap_exceeded = self
            .last_key_time
            .map_or(false, |last| secs_between(now, last) > SESSION_GAP);
        if gap_exceeded {
            self.session_start = Some(now);
        } else if self.session_start.is_none() {
            self.session_start = Some(now);
        }
        self.last_key_time = Some(now);

        self.keystroke_times.push(now);
        self.recent_events.push((now, event.is_delete));
        self.metrics.today_keystrokes += 1;

        self.recompute(now)
    }

    /// Periodic recompute (the runtime's 0.5s tick). Returns a new record if one
    /// was somehow set, though records only ever break on `ingest` in practice.
    pub fn tick(&mut self, now: DateTime<Utc>) -> Option<i64> {
        self.recompute(now)
    }

    /// Reset the per-day counters (called at day rollover).
    pub fn reset_daily(&mut self) {
        self.metrics.today_keystrokes = 0;
    }

    /// Zero the live today-counter and the peak-WPM record (used when the user
    /// erases all data).
    pub fn reset_all_counters(&mut self) {
        self.metrics.today_keystrokes = 0;
        self.metrics.peak_wpm = 0;
    }

    /// Replace the live settings (engines read them on every recompute).
    pub fn set_settings(&mut self, settings: Settings) {
        self.settings = settings;
    }

    fn recompute(&mut self, now: DateTime<Utc>) -> Option<i64> {
        let s = &self.settings;

        // Trim sliding windows.
        self.keystroke_times
            .retain(|t| secs_between(now, *t) <= s.wpm_window);
        self.recent_events
            .retain(|(t, _)| secs_between(now, *t) <= s.delete_window);

        // WPM: keystrokes in window → chars-per-minute → words-per-minute
        // (standard 5-chars-per-word normalisation).
        let chars_per_minute = self.keystroke_times.len() as f64 * (60.0 / s.wpm_window);
        let wpm = (chars_per_minute / CHARS_PER_WORD).round() as i64;
        self.metrics.wpm = wpm;

        // Delete rate over the recent window.
        if self.recent_events.is_empty() {
            self.metrics.delete_rate = 0.0;
        } else {
            let deletes = self.recent_events.iter().filter(|(_, d)| *d).count();
            self.metrics.delete_rate = deletes as f64 / self.recent_events.len() as f64;
        }

        // Idle time.
        self.metrics.idle_seconds = match self.last_key_time {
            Some(last) => secs_between(now, last),
            None => f64::INFINITY,
        };

        // Continuous coding duration (ends after an idle gap).
        self.metrics.continuous_coding_seconds = match self.session_start {
            Some(start) if self.metrics.idle_seconds <= SESSION_GAP => secs_between(now, start),
            _ => 0.0,
        };

        // Flow tracking.
        if wpm >= s.flow_threshold {
            if self.metrics.flow_since.is_none() {
                self.metrics.flow_since = Some(now);
            }
        } else {
            self.metrics.flow_since = None;
        }

        // Personal record. Only celebrate once there is a meaningful baseline.
        if wpm > self.metrics.peak_wpm {
            let previous = self.metrics.peak_wpm;
            self.metrics.peak_wpm = wpm;
            if previous > 0 {
                return Some(wpm);
            }
        }
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::TimeZone;

    fn now0() -> DateTime<Utc> {
        Utc.with_ymd_and_hms(2026, 6, 1, 12, 0, 0).unwrap()
    }

    fn key(now: DateTime<Utc>, delete: bool) -> KeyEvent {
        KeyEvent::new(0, delete, now)
    }

    fn engine() -> MetricsEngine {
        MetricsEngine::new(Settings::default(), 0, 0)
    }

    /// Regression guard for the historical "WPM unit" bug: WPM must be the
    /// 5-chars-per-word normalised value, not raw keystrokes/min.
    #[test]
    fn wpm_uses_five_characters_per_word() {
        let mut e = engine();
        let now = now0();
        // 50 keystrokes inside the 10s window → 300 chars/min → 60 WPM.
        for _ in 0..50 {
            e.ingest(key(now, false));
        }
        assert_eq!(e.metrics.wpm, 60);
        assert_eq!(e.metrics.today_keystrokes, 50);
    }

    #[test]
    fn delete_rate_is_fraction_of_recent_events() {
        let mut e = engine();
        let now = now0();
        for _ in 0..6 {
            e.ingest(key(now, false));
        }
        for _ in 0..4 {
            e.ingest(key(now, true));
        }
        assert!((e.metrics.delete_rate - 0.4).abs() < 0.0001);
    }

    #[test]
    fn reset_daily_clears_today_counter() {
        let mut e = engine();
        let now = now0();
        for _ in 0..10 {
            e.ingest(key(now, false));
        }
        assert_eq!(e.metrics.today_keystrokes, 10);
        e.reset_daily();
        assert_eq!(e.metrics.today_keystrokes, 0);
    }

    #[test]
    fn new_record_fires_above_previous_peak() {
        let mut e = MetricsEngine::new(Settings::default(), 10, 0);
        let now = now0();
        let mut reported: Option<i64> = None;
        // 50 keystrokes/10s → 60 WPM, beating the seeded peak of 10.
        for _ in 0..50 {
            if let Some(w) = e.ingest(key(now, false)) {
                reported = Some(w);
            }
        }
        assert_eq!(reported, Some(60));
        assert_eq!(e.metrics.peak_wpm, 60);
    }
}
