import SwiftUI

/// Shared animation helpers + palette used by the Clawd sprite view.
enum PetTheme {

    /// Outline / ink color used for bubbles and overlay strokes.
    static let outlineColor = Color.black.opacity(0.82)

    /// Breathing scale (gentle idle pulsing). Returns ~0.97 ... 1.03.
    static func breathing(_ t: TimeInterval, speed: Double = 1.0) -> CGFloat {
        1.0 + 0.025 * CGFloat(sin(t * 1.6 * speed))
    }

    /// Vertical paw bob for typing (-1 ... 1), alternating hands via phase.
    static func pawBob(_ t: TimeInterval, phase: Double) -> CGFloat {
        CGFloat(sin(t * 14 + phase))
    }

    /// Excited fast bob used for flow / wakeup (-1 ... 1).
    static func excitedBob(_ t: TimeInterval) -> CGFloat {
        CGFloat(sin(t * 9))
    }

    /// Pulsing glow opacity for flow (0.2 ... 0.6).
    static func glow(_ t: TimeInterval) -> CGFloat {
        0.4 + 0.2 * CGFloat(sin(t * 4))
    }

    /// Decaying bounce height for the 2s wakeup pop.
    static func wakeupBounce(_ phase: TimeInterval) -> CGFloat {
        let damp = max(0, 1 - phase / 2.0)
        return CGFloat(abs(sin(phase * 8)) * damp) * 14
    }
}
