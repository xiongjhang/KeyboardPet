import Foundation

/// Pure decision engine that maps live `Metrics` onto a `PetState`.
///
/// M2 scope: only `idle` and `typing`. The remaining states + transition timing
/// (wakeup, record, night overlay) are layered on in M3.
final class PetStateMachine {

    private(set) var current: PetState = .idle

    /// Seconds of idle below which the pet is considered actively typing.
    private let typingIdleThreshold: TimeInterval = 2.0

    /// Evaluate the next state from a metrics snapshot. Returns the resolved
    /// primary state.
    @discardableResult
    func evaluate(_ m: Metrics, now: Date = Date()) -> PetState {
        let next: PetState
        if m.idleSeconds <= typingIdleThreshold && m.wpm > 0 {
            next = .typing
        } else {
            next = .idle
        }
        current = next
        return next
    }
}
