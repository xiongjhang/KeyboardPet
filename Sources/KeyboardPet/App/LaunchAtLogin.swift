import Foundation
import ServiceManagement

/// Thin wrapper over `SMAppService.mainApp` for the "launch at login" toggle.
///
/// Registration only works for a bundled app (built via `build_app.sh`), not a
/// bare `swift run`; failures are surfaced via `lastError` and leave the toggle
/// reflecting the real system state.
final class LaunchAtLogin: ObservableObject {

    static let shared = LaunchAtLogin()

    @Published var isEnabled: Bool {
        didSet {
            guard !isSyncing, isEnabled != oldValue else { return }
            apply(isEnabled)
        }
    }

    /// Guards the internal status re-sync from re-triggering `didSet`.
    private var isSyncing = false

    /// Human-readable description of the last failed register/unregister, if any.
    @Published private(set) var lastError: String?

    /// Whether toggling is supported in this build (bundled apps only).
    let isSupported: Bool

    private init() {
        // `SMAppService` requires a proper bundle identifier; `swift run` has none.
        isSupported = Bundle.main.bundleIdentifier != nil
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    private func apply(_ enable: Bool) {
        do {
            if enable {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            // Re-sync with the real status so the UI doesn't lie.
            isSyncing = true
            isEnabled = SMAppService.mainApp.status == .enabled
            isSyncing = false
        }
    }
}
