use chrono::{DateTime, Utc};

/// A single, privacy-preserving keyboard event.
///
/// Per the privacy design we ONLY ever capture the physical key code and a
/// timestamp — never the produced character, modifiers, window title, or
/// application name. This invariant is shared by every platform hook.
#[derive(Debug, Clone, Copy)]
pub struct KeyEvent {
    pub key_code: i64,
    pub is_delete: bool,
    pub timestamp: DateTime<Utc>,
}

impl KeyEvent {
    pub fn new(key_code: i64, is_delete: bool, timestamp: DateTime<Utc>) -> Self {
        Self {
            key_code,
            is_delete,
            timestamp,
        }
    }
}
