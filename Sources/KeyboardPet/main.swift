import Foundation
import AppKit

// ─────────────────────────────────────────────────────────────────────────────
// M1 console harness.
//
// Verifies the keyboard monitor + metrics engine by printing live metrics to the
// terminal. Replaced by the SwiftUI app entry point in M2.
// ─────────────────────────────────────────────────────────────────────────────

let monitor = KeyboardMonitor()
let metrics = MetricsEngine()

print("KeyboardPet — M1 keyboard monitor")
print("Privacy: only physical key codes + timestamps are read, never characters.\n")

monitor.onKeyEvent = { event in
    metrics.ingest(event)
}

metrics.start()

// Print a metrics line whenever the snapshot changes.
let cancellable = metrics.$metrics.sink { m in
    let idle = m.idleSeconds.isFinite ? String(format: "%.0fs", m.idleSeconds) : "—"
    let line = String(
        format: "WPM: %4d | delete: %3.0f%% | idle: %5@ | session: %4.0fs | today: %d",
        m.wpm, m.deleteRate * 100, idle as NSString, m.continuousCodingSeconds, m.todayKeystrokes
    )
    print("\r\(line)", terminator: "")
    fflush(stdout)
}

if !monitor.isTrusted {
    print("⚠️  Accessibility permission required.")
    print("   Grant it in System Settings ▸ Privacy & Security ▸ Accessibility,")
    print("   then re-run. Requesting now…\n")
    monitor.requestAccessibilityPermission()
}

if monitor.start() {
    print("✅ Monitoring started. Type anywhere to see metrics. Ctrl-C to quit.\n")
} else {
    print("❌ Could not start monitoring (missing Accessibility permission).")
    print("   Re-run after granting permission.\n")
}

_ = cancellable
// Spin the main run loop so the CGEventTap delivers events.
CFRunLoopRun()
