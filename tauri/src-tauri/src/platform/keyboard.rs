//! Global key-down listener.
//!
//! Uses `rdev`, which installs a low-level keyboard hook per platform
//! (`WH_KEYBOARD_LL` on Windows, a `CGEventTap` on macOS) behind one API.
//!
//! Privacy invariant: we derive ONLY whether each press was a delete key, plus
//! a timestamp. We never read `event.name` (the produced character), modifiers,
//! window title, or application name — mirroring the Swift `KeyboardMonitor`.

use crate::core::KeyEvent;
use chrono::Utc;

/// Keys treated as "delete" actions (Backspace + Forward Delete), matching the
/// macOS keycodes `{51, 117}` used by the Swift app.
fn is_delete_key(key: rdev::Key) -> bool {
    matches!(key, rdev::Key::Backspace | rdev::Key::Delete)
}

/// Start the global key-down listener on a background thread.
///
/// `emit` is called once per key press with a privacy-preserving `KeyEvent`.
/// The listener runs for the lifetime of the process (rdev's `listen` has no
/// stop handle); the app is a long-lived tray agent, so that is acceptable.
pub fn start_listener<F>(emit: F)
where
    F: Fn(KeyEvent) + Send + 'static,
{
    std::thread::spawn(move || {
        let result = rdev::listen(move |event| {
            if let rdev::EventType::KeyPress(key) = event.event_type {
                let timestamp = chrono::DateTime::<Utc>::from(event.time);
                emit(KeyEvent::new(0, is_delete_key(key), timestamp));
            }
        });
        if let Err(err) = result {
            eprintln!("[keyboard] listener stopped: {:?}", err);
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn delete_keys_are_backspace_and_delete() {
        assert!(is_delete_key(rdev::Key::Backspace));
        assert!(is_delete_key(rdev::Key::Delete));
        assert!(!is_delete_key(rdev::Key::KeyA));
        assert!(!is_delete_key(rdev::Key::Space));
    }
}
