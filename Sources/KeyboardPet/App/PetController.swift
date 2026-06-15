import SwiftUI
import Combine

/// Central coordinator wiring the keyboard monitor → metrics engine → state
/// machine, and publishing observable state for the UI.
final class PetController: ObservableObject {

    /// Shared instance, observed by both the pet window and the menu bar.
    static let shared = PetController()

    let monitor = KeyboardMonitor()
    let metrics: MetricsEngine
    let stateMachine = PetStateMachine()
    let experience = ExperienceManager.shared

    /// Current primary pet state (drives rendering).
    @Published private(set) var state: PetState = .idle
    /// Latest metrics snapshot (drives menu bar / stats).
    @Published private(set) var snapshot = Metrics()
    /// Whether Accessibility permission has been granted.
    @Published private(set) var permissionGranted = false
    /// Whether the late-night overlay is active (00:00–05:00).
    @Published private(set) var isNight = false
    /// Reference-time at which the current state began (for transition timing).
    private(set) var stateChangedAt = Date().timeIntervalSinceReferenceDate

    private var cancellables = Set<AnyCancellable>()

    /// Buffered per-(day,hour) keystroke counts, flushed to `StatsStore` in batches.
    private var pendingBuckets: [String: (day: String, hour: Int, count: Int)] = [:]
    private var pendingXP = 0
    private var currentDay = StatsStore.dayString()
    private var flushTimer: Timer?

    init() {
        // Restore lifetime peak so the celebration only fires on genuine records.
        metrics = MetricsEngine(initialPeakWPM: UserDefaults.standard.peakWPM)

        monitor.onKeyEvent = { [weak self] event in
            self?.handleKey(event)
        }
        monitor.onAuthorizationChange = { [weak self] granted in
            DispatchQueue.main.async { self?.permissionGranted = granted }
        }
        // New personal WPM record → temporary celebratory state.
        metrics.onNewRecord = { [weak self] _ in
            self?.stateMachine.triggerRecord()
        }

        metrics.$metrics
            .receive(on: RunLoop.main)
            .sink { [weak self] m in
                guard let self else { return }
                self.snapshot = m
                if m.peakWPM > UserDefaults.standard.peakWPM {
                    UserDefaults.standard.peakWPM = m.peakWPM
                }
                let now = Date()
                self.handleDayRolloverIfNeeded(now)
                self.isNight = PetStateMachine.isNight(now)
                let next = self.stateMachine.evaluate(m, now: now)
                if next != self.state {
                    self.state = next
                    self.stateChangedAt = now.timeIntervalSinceReferenceDate
                }
            }
            .store(in: &cancellables)
    }

    /// Begin monitoring. Requests Accessibility permission if not yet granted.
    func start() {
        permissionGranted = monitor.isTrusted
        if !monitor.isTrusted {
            monitor.requestAccessibilityPermission()
        }
        metrics.start()
        monitor.start()

        // Batch-persist buffered stats / XP every 60s (perf budget).
        let t = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            self?.flush()
        }
        RunLoop.main.add(t, forMode: .common)
        flushTimer = t

        // Retry starting the tap until permission is granted (the user may grant
        // it after launch without relaunching).
        if !monitor.isRunning {
            schedulePermissionRetry()
        }
    }

    private func handleKey(_ event: KeyEvent) {
        metrics.ingest(event)

        let calendar = Calendar.current
        let day = StatsStore.dayString(event.timestamp, calendar: calendar)
        let hour = calendar.component(.hour, from: event.timestamp)
        let key = "\(day)-\(hour)"
        if var bucket = pendingBuckets[key] {
            bucket.count += 1
            pendingBuckets[key] = bucket
        } else {
            pendingBuckets[key] = (day, hour, 1)
        }
        pendingXP += 1
    }

    /// Flush buffered keystroke counts to the store and award accumulated XP.
    func flush() {
        for (_, bucket) in pendingBuckets {
            StatsStore.shared.add(count: bucket.count, day: bucket.day, hour: bucket.hour)
        }
        pendingBuckets.removeAll()
        if pendingXP > 0 {
            experience.award(keystrokes: pendingXP)
            pendingXP = 0
        }
    }

    private func handleDayRolloverIfNeeded(_ now: Date) {
        let today = StatsStore.dayString(now)
        if today != currentDay {
            flush()                 // persist yesterday's tail
            metrics.resetDaily()    // reset today's live counter
            currentDay = today
        }
    }

    private func schedulePermissionRetry() {
        let t = Timer(timeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if self.monitor.isTrusted {
                self.permissionGranted = true
                if self.monitor.start() { timer.invalidate() }
            }
        }
        RunLoop.main.add(t, forMode: .common)
    }
}
