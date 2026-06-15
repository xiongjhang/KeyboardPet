import Foundation

/// Pure decision engine mapping live `Metrics` onto a `PetState`.
///
/// Implements the full design state machine: priority resolution, the timed
/// `record` (3s) and `wakeup` (2s) transitions, and the idle→thinking→sleepy→
/// sleeping progression. `night` is handled as an overlay outside this enum.
final class PetStateMachine {

    private(set) var current: PetState = .idle

    // MARK: Thresholds (seconds), per the design's state table.

    /// Idle below this = actively typing.
    private let activeThreshold: TimeInterval = 2.0
    private let thinkingAfter: TimeInterval = 30
    private let sleepyAfter: TimeInterval = 120
    private let sleepingAfter: TimeInterval = 300

    /// Flow requires WPM above threshold sustained for this long.
    private let flowSustain: TimeInterval = 30
    private let deleteRateThreshold = 0.5

    private let recordDuration: TimeInterval = 3
    private let wakeupDuration: TimeInterval = 2

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
            // 3-5. Active typing states, in priority order.
            if let since = m.flowSince, now.timeIntervalSince(since) >= flowSustain {
                next = .flow
            } else if m.deleteRate > deleteRateThreshold {
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

    /// Whether the system clock is in the late-night window (00:00–05:00).
    /// Drives the `night` overlay, independent of the primary state.
    static func isNight(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= 0 && hour < 5
    }
}
