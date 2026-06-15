import SwiftUI
import AppKit

@main
struct KeyboardPetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var controller = PetController.shared

    var body: some Scene {
        // Menu bar entry with a live status summary.
        MenuBarExtra {
            MenuBarContent()
                .environmentObject(controller)
        } label: {
            Text(controller.state.emoji)
        }

        Window("KeyboardPet 统计", id: "stats") {
            StatsPanel()
                .environmentObject(controller)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }
    }
}

/// Owns the floating pet window. State lives in `PetController.shared`.
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var petWindowController: PetWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-style agent: no Dock icon.
        NSApp.setActivationPolicy(.accessory)

        let controller = PetController.shared
        let root = AnyView(PetView().environmentObject(controller))
        let windowController = PetWindowController(rootView: root)
        windowController.show()
        petWindowController = windowController

        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Persist any buffered keystrokes / XP before exiting.
        PetController.shared.flush()
    }
}
