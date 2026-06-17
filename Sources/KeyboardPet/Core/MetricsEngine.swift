import Foundation
import Combine

/// A point-in-time snapshot of the live keyboard metrics.
struct Metrics {
    var wpm: Int = 0
    var deleteRate: Double = 0          // 0.0 ... 1.0 over the recent window
    var idleSeconds: TimeInterval = 0   // seconds since the last keystroke
    var continuousCodingSeconds: TimeInterval = 0
    var todayKeystrokes: Int = 0
    var peakWPM: Int = 0
    /// Date since which WPM has continuously been above the flow threshold,
    /// or nil if it is currently below.
    var flowSince: Date?
}

/// Computes real-time keyboard metrics from a stream of `KeyEvent`s.
///
/// Only derived numbers are kept — never the events' semantic content.
final class MetricsEngine: ObservableObject {

    @Published private(set) var metrics = Metrics()

    // MARK: Tuning

    /// User-tunable thresholds (read live so edits apply without a restart).
    private var settings: PetSettings { .shared }

    /// Sliding window used to estimate WPM.
    private var wpmWindow: TimeInterval { settings.wpmWindow }
    /// Standard typing-test convention: one "word" == 5 characters/keystrokes.
    /// This matches EdClub / TypeRacer / Monkeytype, so the number is comparable.
    private let charsPerWord = 5.0
    /// Window over which the delete ratio is measured.
    private var deleteWindow: TimeInterval { settings.deleteWindow }
    /// Idle gap that ends a continuous-coding session.
    private let sessionGap: TimeInterval = 60
    /// WPM threshold considered "flow" (real WPM, i.e. post 5-char normalisation).
    private var flowThreshold: Int { settings.flowThreshold }

    // MARK: State

    private var keystrokeTimes: [Date] = []        // within wpmWindow
    private var recentEvents: [(date: Date, isDelete: Bool)] = []  // within deleteWindow
    private var lastKeyTime: Date?
    private var sessionStart: Date?
    private var timer: Timer?

    /// Called whenever the personal WPM record is broken.
    var onNewRecord: ((Int) -> Void)?

    init(initialPeakWPM: Int = 0, initialTodayKeystrokes: Int = 0) {
        metrics.peakWPM = initialPeakWPM
        metrics.todayKeystrokes = initialTodayKeystrokes
    }

    func start() {
        timer?.invalidate()
        // Periodic recompute so idle time / WPM decay even with no new keys.
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.recompute()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Ingest a new keyboard event.
    func ingest(_ event: KeyEvent) {
        let now = event.timestamp

        // Continuous-coding session bookkeeping.
        if let last = lastKeyTime, now.timeIntervalSince(last) > sessionGap {
            sessionStart = now
        } else if sessionStart == nil {
            sessionStart = now
        }
        lastKeyTime = now

        keystrokeTimes.append(now)
        recentEvents.append((now, event.isDelete))
        metrics.todayKeystrokes += 1

        recompute(now: now)
    }

    /// Reset the per-day counters (called at day rollover).
    func resetDaily() {
        metrics.todayKeystrokes = 0
    }

    /// Zero the live today-counter and the peak-WPM record (used when the user
    /// erases all data).
    func resetAllCounters() {
        metrics.todayKeystrokes = 0
        metrics.peakWPM = 0
    }

    private func recompute(now: Date = Date()) {
        // Trim sliding windows.
        keystrokeTimes.removeAll { now.timeIntervalSince($0) > wpmWindow }
        recentEvents.removeAll { now.timeIntervalSince($0.date) > deleteWindow }

        // WPM: keystrokes in window → chars-per-minute → words-per-minute
        // (standard 5-chars-per-word normalisation).
        let charsPerMinute = Double(keystrokeTimes.count) * (60.0 / wpmWindow)
        let wpm = Int((charsPerMinute / charsPerWord).rounded())
        metrics.wpm = wpm

        // Delete rate over the recent window.
        if recentEvents.isEmpty {
            metrics.deleteRate = 0
        } else {
            let deletes = recentEvents.filter { $0.isDelete }.count
            metrics.deleteRate = Double(deletes) / Double(recentEvents.count)
        }

        // Idle time.
        if let last = lastKeyTime {
            metrics.idleSeconds = now.timeIntervalSince(last)
        } else {
            metrics.idleSeconds = .infinity
        }

        // Continuous coding duration (ends after an idle gap).
        if let start = sessionStart, metrics.idleSeconds <= sessionGap {
            metrics.continuousCodingSeconds = now.timeIntervalSince(start)
        } else {
            metrics.continuousCodingSeconds = 0
        }

        // Flow tracking.
        if wpm >= flowThreshold {
            if metrics.flowSince == nil { metrics.flowSince = now }
        } else {
            metrics.flowSince = nil
        }

        // Personal record.
        if wpm > metrics.peakWPM {
            let previous = metrics.peakWPM
            metrics.peakWPM = wpm
            // Only celebrate once there is a meaningful baseline.
            if previous > 0 {
                onNewRecord?(wpm)
            }
        }
    }
}
