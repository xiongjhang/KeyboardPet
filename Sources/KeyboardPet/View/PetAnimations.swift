import SwiftUI

/// Per-state visual theme + shared animation helpers used by `PetView`.
enum PetTheme {

    /// Body fill color for a given state.
    static func bodyColor(for state: PetState) -> Color {
        switch state {
        case .idle:     return Color(red: 0.55, green: 0.80, blue: 0.95)
        case .typing:   return Color(red: 0.45, green: 0.78, blue: 0.62)
        case .flow:     return Color(red: 1.00, green: 0.72, blue: 0.30)
        case .deleting: return Color(red: 0.92, green: 0.55, blue: 0.55)
        case .thinking: return Color(red: 0.72, green: 0.70, blue: 0.92)
        case .sleepy:   return Color(red: 0.66, green: 0.70, blue: 0.86)
        case .sleeping: return Color(red: 0.50, green: 0.54, blue: 0.74)
        case .wakeup:   return Color(red: 1.00, green: 0.85, blue: 0.45)
        case .record:   return Color(red: 1.00, green: 0.66, blue: 0.80)
        }
    }

    static let cheekColor = Color(red: 1.0, green: 0.6, blue: 0.65).opacity(0.7)
    static let outlineColor = Color.black.opacity(0.82)

    /// Breathing scale (gentle idle pulsing). Returns ~0.97 ... 1.03.
    static func breathing(_ t: TimeInterval, speed: Double = 1.0) -> CGFloat {
        1.0 + 0.025 * CGFloat(sin(t * 1.6 * speed))
    }

    /// Blink openness 0 (closed) ... 1 (open). Blinks briefly every ~4s.
    static func blink(_ t: TimeInterval) -> CGFloat {
        let cycle = t.truncatingRemainder(dividingBy: 4.0)
        if cycle > 3.85 {
            // 0.15s blink, smooth close/open.
            let p = (cycle - 3.85) / 0.15
            return CGFloat(abs(cos(p * .pi)))
        }
        return 1.0
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
