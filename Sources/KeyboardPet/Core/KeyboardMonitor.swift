import Foundation
import CoreGraphics
import AppKit

/// A single, privacy-preserving keyboard event.
///
/// Per the privacy design, we ONLY ever capture the physical key code and a
/// timestamp. We never capture the produced character, modifiers, window title,
/// or application name.
struct KeyEvent {
    let keyCode: Int64
    let isDelete: Bool
    let timestamp: Date
}

/// Key codes we treat as "delete" actions (Backspace + Forward Delete).
private let deleteKeyCodes: Set<Int64> = [51, 117]

/// Monitors global key-down events via `CGEventTap`.
///
/// Requires Accessibility permission. The tap callback is a C function pointer,
/// so we forward the event to the owning instance through the `refcon` pointer.
final class KeyboardMonitor {

    /// Called on the main thread for every captured key-down event.
    var onKeyEvent: ((KeyEvent) -> Void)?

    /// Called when the permission/authorization state changes.
    var onAuthorizationChange: ((Bool) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isRunning = false

    /// Whether the process is currently trusted for Accessibility.
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt the user to grant Accessibility permission (opens the system dialog
    /// the first time, otherwise is a no-op).
    @discardableResult
    func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Attempt to start the event tap. Returns false if permission is missing or
    /// the tap could not be created.
    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }
        guard isTrusted else {
            onAuthorizationChange?(false)
            return false
        }

        let mask = (1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else {
            onAuthorizationChange?(false)
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        self.isRunning = true
        onAuthorizationChange?(true)
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isRunning = false
    }

    private func handle(type: CGEventType, event: CGEvent) {
        // The system may disable the tap (timeout / user-input overload).
        // Re-enable it so monitoring survives.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }

        guard type == .keyDown else { return }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let keyEvent = KeyEvent(
            keyCode: keyCode,
            isDelete: deleteKeyCodes.contains(keyCode),
            timestamp: Date()
        )

        // Tap callback runs on the main run loop already, but dispatch defensively
        // to guarantee main-thread delivery to UI/state observers.
        DispatchQueue.main.async { [weak self] in
            self?.onKeyEvent?(keyEvent)
        }
    }
}
