//! Pure decision engine mapping live `Metrics` onto a `PetState`.
//!
//! Ported from `PetState` + `PetStateMachine`. Implements the full design state
//! machine: priority resolution, the timed `record` (3s) and `wakeup` (2s)
//! transitions, and the idle→thinking→sleepy→sleeping progression. `night` is
//! handled as an overlay outside this enum.

use crate::core::metrics::secs_between;
use crate::core::{Metrics, Settings};
use chrono::{DateTime, Duration, TimeZone, Timelike, Utc};

/// The full set of mutually-exclusive primary pet states.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PetState {
    Idle,
    Typing,
    Flow,
    Deleting,
    Thinking,
    Sleepy,
    Sleeping,
    Wakeup,
    Record,
}

impl PetState {
    /// Higher value = higher priority when several conditions match.
    pub fn priority(self) -> i32 {
        match self {
            PetState::Record => 9,
            PetState::Wakeup => 8,
            PetState::Flow => 7,
            PetState::Deleting => 6,
            PetState::Typing => 5,
            PetState::Thinking => 4,
            PetState::Sleepy => 3,
            PetState::Sleeping => 2,
            PetState::Idle => 1,
        }
    }

    /// Stable identifier; matches the PNG sprite prefixes (`idle_0.png`, …).
    pub fn as_str(self) -> &'static str {
        match self {
            PetState::Idle => "idle",
            PetState::Typing => "typing",
            PetState::Flow => "flow",
            PetState::Deleting => "deleting",
            PetState::Thinking => "thinking",
            PetState::Sleepy => "sleepy",
            PetState::Sleeping => "sleeping",
            PetState::Wakeup => "wakeup",
            PetState::Record => "record",
        }
    }

    /// Human-readable label used in the tray / stats.
    pub fn display_name(self) -> &'static str {
        match self {
            PetState::Idle => "发呆",
            PetState::Typing => "打字中",
            PetState::Flow => "心流",
            PetState::Deleting => "纠结",
            PetState::Thinking => "思考",
            PetState::Sleepy => "犯困",
            PetState::Sleeping => "睡着了",
            PetState::Wakeup => "惊醒",
            PetState::Record => "破纪录！",
        }
    }

    /// Emoji shorthand used as a quick visual cue.
    pub fn emoji(self) -> &'static str {
        match self {
            PetState::Idle => "😊",
            PetState::Typing => "⌨️",
            PetState::Flow => "🔥",
            PetState::Deleting => "😰",
            PetState::Thinking => "🤔",
            PetState::Sleepy => "😪",
            PetState::Sleeping => "💤",
            PetState::Wakeup => "😲",
            PetState::Record => "🎉",
        }
    }
}

/// Add a fractional number of seconds to an instant.
fn add_secs(now: DateTime<Utc>, seconds: f64) -> DateTime<Utc> {
    now + Duration::milliseconds((seconds * 1000.0) as i64)
}

pub struct PetStateMachine {
    current: PetState,
    settings: Settings,
    record_until: Option<DateTime<Utc>>,
    wakeup_until: Option<DateTime<Utc>>,
}

impl PetStateMachine {
    pub fn new(settings: Settings) -> Self {
        Self {
            current: PetState::Idle,
            settings,
            record_until: None,
            wakeup_until: None,
        }
    }

    pub fn current(&self) -> PetState {
        self.current
    }

    /// Replace the live settings (read on every `evaluate`).
    pub fn set_settings(&mut self, settings: Settings) {
        self.settings = settings;
    }

    /// Begin the temporary celebratory `record` state.
    pub fn trigger_record(&mut self, now: DateTime<Utc>) {
        self.record_until = Some(add_secs(now, self.settings.record_duration));
    }

    /// Evaluate the next primary state. Resolution order matches the design's
    /// priority list (record > wakeup > flow > deleting > typing > thinking >
    /// sleepy > sleeping > idle).
    pub fn evaluate(&mut self, m: &Metrics, now: DateTime<Utc>) -> PetState {
        let s = self.settings.clone();

        // 1. record — highest priority, temporary overlay.
        if let Some(until) = self.record_until {
            if now < until {
                self.current = PetState::Record;
                return PetState::Record;
            }
            self.record_until = None;
        }

        let just_typed = m.idle_seconds <= s.active_threshold && m.wpm > 0;

        // 2. wakeup — fixed-length transition out of sleeping.
        if let Some(until) = self.wakeup_until {
            if now < until {
                self.current = PetState::Wakeup;
                return PetState::Wakeup;
            }
            self.wakeup_until = None;
        }
        if self.current == PetState::Sleeping && just_typed {
            self.wakeup_until = Some(add_secs(now, s.wakeup_duration));
            self.current = PetState::Wakeup;
            return PetState::Wakeup;
        }

        let next = if just_typed {
            // 3-5. Active typing states, in priority order (each toggleable).
            let sustained_flow = m
                .flow_since
                .map_or(false, |since| secs_between(now, since) >= s.flow_sustain);
            if s.flow_enabled && sustained_flow {
                PetState::Flow
            } else if s.deleting_enabled && m.delete_rate > s.delete_rate_threshold {
                PetState::Deleting
            } else {
                PetState::Typing
            }
        } else {
            // 6-9. Idle progression by elapsed idle time.
            let idle = m.idle_seconds;
            if idle >= s.sleeping_after {
                PetState::Sleeping
            } else if idle >= s.sleepy_after {
                PetState::Sleepy
            } else if idle >= s.thinking_after {
                PetState::Thinking
            } else {
                PetState::Idle
            }
        };

        self.current = next;
        next
    }

    /// Whether the given instant falls in the user-defined late-night window.
    /// Drives the `night` overlay, independent of the primary state.
    ///
    /// `start == end` (or night disabled) means no night window; `start > end`
    /// wraps past midnight (e.g. 23 → 6). The hour is read in the timezone of
    /// the passed datetime.
    pub fn is_night<Tz: TimeZone>(now: DateTime<Tz>, s: &Settings) -> bool {
        if !s.night_enabled {
            return false;
        }
        let (start, end) = (s.night_start_hour, s.night_end_hour);
        if start == end {
            return false;
        }
        let hour = now.hour();
        if start < end {
            hour >= start && hour < end
        } else {
            hour >= start || hour < end // wraps midnight
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::TimeZone;

    fn now0() -> DateTime<Utc> {
        Utc.with_ymd_and_hms(2026, 6, 1, 12, 0, 0).unwrap()
    }

    fn sm() -> PetStateMachine {
        PetStateMachine::new(Settings::default())
    }

    /// Mirrors the Swift `typing(...)` test helper (defaults: wpm 10, idle 0).
    fn typing(wpm: i64, idle: f64, delete_rate: f64, flow_since: Option<DateTime<Utc>>) -> Metrics {
        let mut m = Metrics::default();
        m.wpm = wpm;
        m.idle_seconds = idle;
        m.delete_rate = delete_rate;
        m.flow_since = flow_since;
        m
    }

    fn default_typing() -> Metrics {
        typing(10, 0.0, 0.0, None)
    }

    #[test]
    fn active_typing_is_typing() {
        let mut s = sm();
        assert_eq!(s.evaluate(&default_typing(), now0()), PetState::Typing);
    }

    #[test]
    fn idle_progression() {
        let mut s = sm();
        let now = now0();
        assert_eq!(s.evaluate(&typing(0, 0.0, 0.0, None), now), PetState::Idle);
        assert_eq!(
            s.evaluate(&typing(0, 40.0, 0.0, None), now),
            PetState::Thinking
        ); // > 30
        assert_eq!(
            s.evaluate(&typing(0, 150.0, 0.0, None), now),
            PetState::Sleepy
        ); // > 120
        assert_eq!(
            s.evaluate(&typing(0, 400.0, 0.0, None), now),
            PetState::Sleeping
        ); // > 300
    }

    #[test]
    fn deleting_beats_typing() {
        let mut s = sm();
        assert_eq!(
            s.evaluate(&typing(10, 0.0, 0.6, None), now0()),
            PetState::Deleting
        );
    }

    #[test]
    fn flow_requires_sustained_window() {
        let mut s = sm();
        let now = now0();
        // flow_since only 5s ago — not sustained long enough (default 30s).
        assert_eq!(
            s.evaluate(&typing(10, 0.0, 0.0, Some(now - Duration::seconds(5))), now),
            PetState::Typing
        );
        // 31s ago — sustained → flow.
        assert_eq!(
            s.evaluate(&typing(10, 0.0, 0.0, Some(now - Duration::seconds(31))), now),
            PetState::Flow
        );
    }

    #[test]
    fn record_overrides_everything() {
        let mut s = sm();
        let now = now0();
        s.trigger_record(now);
        assert_eq!(
            s.evaluate(&typing(0, 9999.0, 0.0, None), now),
            PetState::Record
        );
        // After the record window elapses, fall back to the real state.
        let later = now + Duration::seconds(10);
        assert_eq!(
            s.evaluate(&typing(0, 9999.0, 0.0, None), later),
            PetState::Sleeping
        );
    }

    #[test]
    fn wakeup_triggered_from_sleeping() {
        let mut s = sm();
        let now = now0();
        assert_eq!(
            s.evaluate(&typing(0, 400.0, 0.0, None), now),
            PetState::Sleeping
        );
        assert_eq!(s.evaluate(&default_typing(), now), PetState::Wakeup);
    }

    #[test]
    fn is_night_respects_window() {
        // Default night window is 00:00–05:00.
        let s = Settings::default();
        assert!(PetStateMachine::is_night(
            Utc.with_ymd_and_hms(2026, 6, 1, 2, 0, 0).unwrap(),
            &s
        ));
        assert!(!PetStateMachine::is_night(
            Utc.with_ymd_and_hms(2026, 6, 1, 10, 0, 0).unwrap(),
            &s
        ));
    }
}
