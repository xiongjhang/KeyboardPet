import Foundation

/// Pure decision engine mapping live `Metrics` onto a `PetState`.
///
/// Implements the full design state machine: priority resolution, the timed
/// `record` (3s) and `wakeup` (2s) transitions, and the idle→thinking→sleepy→
/// sleeping progression. `night` is handled as an overlay outside this enum.
final class PetStateMachine {

    private(set) var current: PetState = .idle

    // MARK: Thresholds — user-tunable, read live from `PetSettings`.

    private var settings: PetSettings { .shared }

    /// Idle below this = actively typing.
    private var activeThreshold: TimeInterval { settings.activeThreshold }
    private var thinkingAfter: TimeInterval { settings.thinkingAfter }
    private var sleepyAfter: TimeInterval { settings.sleepyAfter }
    private var sleepingAfter: TimeInterval { settings.sleepingAfter }

    /// Flow requires WPM above threshold sustained for this long.
    private var flowSustain: TimeInterval { settings.flowSustain }
    private var deleteRateThreshold: Double { settings.deleteRateThreshold }

    private var recordDuration: TimeInterval { settings.recordDuration }
    private var wakeupDuration: TimeInterval { settings.wakeupDuration }

    // MARK: Timed-transition bookkeeping

    private var recordUntil: Date?
    private var wakeupUntil: Date?

    /// Begin the temporary celebratory `record` state.
    func triggerRecord(now: Date = Date()) {
        recordUntil = now.addingTimeInterval(recordDuration)
    }

    /// Evaluate the next primary state. Resolution order matches the design's
    /// priority list (record > wakeup > flow > deleting > typing > thinking >
    /// sleepy > sleeping > idle).
    @discardableResult
    func evaluate(_ m: Metrics, now: Date = Date()) -> PetState {
        // 1. record — highest priority, temporary overlay.
        if let until = recordUntil {
            if now < until { current = .record; return .record }
            recordUntil = nil
        }

        let justTyped = m.idleSeconds <= activeThreshold && m.wpm > 0

        // 2. wakeup — fixed-length transition out of sleeping.
        if let until = wakeupUntil {
            if now < until { current = .wakeup; return .wakeup }
            wakeupUntil = nil
        }
        if current == .sleeping && justTyped {
            wakeupUntil = now.addingTimeInterval(wakeupDuration)
            current = .wakeup
            return .wakeup
        }

        let next: PetState
        if justTyped {
            // 3-5. Active typing states, in priority order (each toggleable).
            if settings.flowEnabled, let since = m.flowSince,
               now.timeIntervalSince(since) >= flowSustain {
                next = .flow
            } else if settings.deletingEnabled, m.deleteRate > deleteRateThreshold {
                next = .deleting
            } else {
                next = .typing
            }
        } else {
            // 6-9. Idle progression by elapsed idle time.
            let idle = m.idleSeconds
            if idle >= sleepingAfter {
                next = .sleeping
            } else if idle >= sleepyAfter {
                next = .sleepy
            } else if idle >= thinkingAfter {
                next = .thinking
            } else {
                next = .idle
            }
        }

        current = next
        return next
    }

    /// Whether the system clock is in the user-defined late-night window.
    /// Drives the `night` overlay, independent of the primary state.
    ///
    /// `start == end` (or night disabled) means no night window; `start > end`
    /// wraps past midnight (e.g. 23 → 6).
    static func isNight(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let s = PetSettings.shared
        guard s.nightEnabled else { return false }
        let start = s.nightStartHour, end = s.nightEndHour
        guard start != end else { return false }
        let hour = calendar.component(.hour, from: date)
        if start < end { return hour >= start && hour < end }
        return hour >= start || hour < end   // wraps midnight
    }
}
