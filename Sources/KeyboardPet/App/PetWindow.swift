import AppKit
import SwiftUI
import Combine

/// Borderless window that can still be dragged and become key.
final class PetPanel: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Manages the transparent, always-on-top, draggable pet window.
///
/// Behavior (per design): floating level, clear background, follows the main
/// display, draggable by its body, remembers its last position.
final class PetWindowController {

    let window: PetPanel
    /// Base logical canvas size (scale 1.0); the actual window is this × petScale.
    static let petSize = CGSize(width: 200, height: 200)

    private var cancellables = Set<AnyCancellable>()

    init(rootView: AnyView) {
        let size = PetWindowController.petSize
        window = PetPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let host = NSHostingView(rootView: rootView)
        host.frame = NSRect(origin: .zero, size: size)
        host.autoresizingMask = [.width, .height]   // follow window resizes
        window.contentView = host

        positionWindow()
        applyScale()

        // Persist position whenever the user drags the pet.
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowMoved),
            name: NSWindow.didMoveNotification, object: window
        )

        // Resize the floating window live when the user changes petScale.
        PetSettings.shared.objectWillChange
            .sink { [weak self] in
                // Defer so we read the value *after* it has been written.
                DispatchQueue.main.async { self?.applyScale() }
            }
            .store(in: &cancellables)
    }

    /// Resize the window to the base canvas × `petScale`, anchored at its
    /// bottom-left so the pet keeps its footing on screen.
    private func applyScale() {
        let scale = CGFloat(PetSettings.shared.petScale)
        let base = PetWindowController.petSize
        let newSize = CGSize(width: base.width * scale, height: base.height * scale)
        guard window.frame.size != newSize else { return }
        window.setFrame(NSRect(origin: window.frame.origin, size: newSize),
                        display: true, animate: false)
    }

    func show() {
        window.orderFrontRegardless()
    }

    /// Place the window at the saved origin, or default to the bottom-right of
    /// the main display.
    private func positionWindow() {
        let size = PetWindowController.petSize
        if let saved = UserDefaults.standard.petWindowOrigin {
            window.setFrameOrigin(saved)
            return
        }
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let margin: CGFloat = 24
        let origin = CGPoint(
            x: visible.maxX - size.width - margin,
            y: visible.minY + margin
        )
        window.setFrameOrigin(origin)
    }

    @objc private func windowMoved() {
        UserDefaults.standard.petWindowOrigin = window.frame.origin
    }
}
