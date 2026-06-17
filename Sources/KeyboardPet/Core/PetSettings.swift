import Foundation
import Combine

/// User-tunable thresholds for the state machine and metrics engine.
///
/// UserDefaults is the single source of truth; the engines read
/// `PetSettings.shared` on every tick, so edits apply live (no restart). The
/// `Default` values double as the "reset to defaults" target.
final class PetSettings: ObservableObject {

    /// Shared instance read live by the engines. Declared `var` so tests can
    /// swap in an isolated instance backed by a throwaway `UserDefaults` suite
    /// (and restore it afterwards) without touching the user's real settings.
    static var shared = PetSettings()

    /// Default values — the single place that defines "factory settings".
    enum Default {
        // Appearance.
        static let petScale = 1.0              // 1.0 == base 200pt window
        // Idle progression (seconds).
        static let thinkingAfter = 30.0
        static let sleepyAfter = 120.0
        static let sleepingAfter = 300.0
        // Flow.
        static let flowEnabled = true
        static let flowThreshold = 60          // real WPM
        static let flowSustain = 30.0          // seconds
        // Deleting.
        static let deletingEnabled = true
        static let deleteRateThreshold = 0.5   // 0...1
        // Night (hours of day; start == end disables; start > end wraps midnight).
        static let nightEnabled = true
        static let nightStartHour = 0
        static let nightEndHour = 5
        // Active-typing detection.
        static let activeThreshold = 2.0       // seconds since last key
        // Advanced.
        static let wpmWindow = 10.0            // seconds
        static let deleteWindow = 20.0         // seconds
        static let recordDuration = 3.0        // seconds
        static let wakeupDuration = 2.0        // seconds
    }

    private enum Key {
        static let petScale = "cfg.petScale"
        static let thinkingAfter = "cfg.thinkingAfter"
        static let sleepyAfter = "cfg.sleepyAfter"
        static let sleepingAfter = "cfg.sleepingAfter"
        static let flowEnabled = "cfg.flowEnabled"
        static let flowThreshold = "cfg.flowThreshold"
        static let flowSustain = "cfg.flowSustain"
        static let deletingEnabled = "cfg.deletingEnabled"
        static let deleteRateThreshold = "cfg.deleteRateThreshold"
        static let nightEnabled = "cfg.nightEnabled"
        static let nightStartHour = "cfg.nightStartHour"
        static let nightEndHour = "cfg.nightEndHour"
        static let activeThreshold = "cfg.activeThreshold"
        static let wpmWindow = "cfg.wpmWindow"
        static let deleteWindow = "cfg.deleteWindow"
        static let recordDuration = "cfg.recordDuration"
        static let wakeupDuration = "cfg.wakeupDuration"

        static let all = [
            petScale,
            thinkingAfter, sleepyAfter, sleepingAfter, flowEnabled, flowThreshold,
            flowSustain, deletingEnabled, deleteRateThreshold, nightEnabled,
            nightStartHour, nightEndHour, activeThreshold, wpmWindow, deleteWindow,
            recordDuration, wakeupDuration,
        ]
    }

    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    // MARK: Appearance

    /// On-screen scale of the desktop crab (1.0 == base size).
    var petScale: Double {
        get { read(Key.petScale, Default.petScale) }
        set { write(newValue, Key.petScale) }
    }

    // MARK: Idle progression

    var thinkingAfter: Double {
        get { read(Key.thinkingAfter, Default.thinkingAfter) }
        set { write(newValue, Key.thinkingAfter) }
    }
    var sleepyAfter: Double {
        get { read(Key.sleepyAfter, Default.sleepyAfter) }
        set { write(newValue, Key.sleepyAfter) }
    }
    var sleepingAfter: Double {
        get { read(Key.sleepingAfter, Default.sleepingAfter) }
        set { write(newValue, Key.sleepingAfter) }
    }

    // MARK: Flow

    var flowEnabled: Bool {
        get { read(Key.flowEnabled, Default.flowEnabled) }
        set { write(newValue, Key.flowEnabled) }
    }
    var flowThreshold: Int {
        get { read(Key.flowThreshold, Default.flowThreshold) }
        set { write(newValue, Key.flowThreshold) }
    }
    var flowSustain: Double {
        get { read(Key.flowSustain, Default.flowSustain) }
        set { write(newValue, Key.flowSustain) }
    }

    // MARK: Deleting

    var deletingEnabled: Bool {
        get { read(Key.deletingEnabled, Default.deletingEnabled) }
        set { write(newValue, Key.deletingEnabled) }
    }
    var deleteRateThreshold: Double {
        get { read(Key.deleteRateThreshold, Default.deleteRateThreshold) }
        set { write(newValue, Key.deleteRateThreshold) }
    }

    // MARK: Night

    var nightEnabled: Bool {
        get { read(Key.nightEnabled, Default.nightEnabled) }
        set { write(newValue, Key.nightEnabled) }
    }
    var nightStartHour: Int {
        get { read(Key.nightStartHour, Default.nightStartHour) }
        set { write(newValue, Key.nightStartHour) }
    }
    var nightEndHour: Int {
        get { read(Key.nightEndHour, Default.nightEndHour) }
        set { write(newValue, Key.nightEndHour) }
    }

    // MARK: Active-typing detection

    var activeThreshold: Double {
        get { read(Key.activeThreshold, Default.activeThreshold) }
        set { write(newValue, Key.activeThreshold) }
    }

    // MARK: Advanced

    var wpmWindow: Double {
        get { read(Key.wpmWindow, Default.wpmWindow) }
        set { write(newValue, Key.wpmWindow) }
    }
    var deleteWindow: Double {
        get { read(Key.deleteWindow, Default.deleteWindow) }
        set { write(newValue, Key.deleteWindow) }
    }
    var recordDuration: Double {
        get { read(Key.recordDuration, Default.recordDuration) }
        set { write(newValue, Key.recordDuration) }
    }
    var wakeupDuration: Double {
        get { read(Key.wakeupDuration, Default.wakeupDuration) }
        set { write(newValue, Key.wakeupDuration) }
    }

    /// Restore every value to its factory default.
    func resetToDefaults() {
        objectWillChange.send()
        Key.all.forEach { defaults.removeObject(forKey: $0) }
    }

    // MARK: Backing store helpers

    private func read(_ key: String, _ fallback: Double) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }
    private func read(_ key: String, _ fallback: Int) -> Int {
        defaults.object(forKey: key) == nil ? fallback : defaults.integer(forKey: key)
    }
    private func read(_ key: String, _ fallback: Bool) -> Bool {
        defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
    }
    private func write<T>(_ value: T, _ key: String) {
        objectWillChange.send()
        defaults.set(value, forKey: key)
    }
}
