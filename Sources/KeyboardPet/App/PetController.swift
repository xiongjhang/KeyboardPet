import SwiftUI
import Combine

/// Central coordinator wiring the keyboard monitor → metrics engine → state
/// machine, and publishing observable state for the UI.
final class PetController: ObservableObject {

    let monitor = KeyboardMonitor()
    let metrics: MetricsEngine
    let stateMachine = PetStateMachine()

    /// Current primary pet state (drives rendering).
    @Published private(set) var state: PetState = .idle
    /// Latest metrics snapshot (drives menu bar / stats).
    @Published private(set) var snapshot = Metrics()
    /// Whether Accessibility permission has been granted.
    @Published private(set) var permissionGranted = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        metrics = MetricsEngine()

        monitor.onKeyEvent = { [weak self] event in
            self?.metrics.ingest(event)
        }
        monitor.onAuthorizationChange = { [weak self] granted in
            DispatchQueue.main.async { self?.permissionGranted = granted }
        }

        metrics.$metrics
            .receive(on: RunLoop.main)
            .sink { [weak self] m in
                guard let self else { return }
                self.snapshot = m
                let next = self.stateMachine.evaluate(m)
                if next != self.state { self.state = next }
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

        // Retry starting the tap until permission is granted (the user may grant
        // it after launch without relaunching).
        if !monitor.isRunning {
            schedulePermissionRetry()
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
