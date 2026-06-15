import SwiftUI
import AppKit

@main
struct KeyboardPetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The pet window is managed imperatively by the AppDelegate (AppKit).
        // The menu bar entry (MenuBarExtra) is added in M4.
        Settings {
            EmptyView()
        }
    }
}

/// Owns the long-lived controller and the floating pet window.
final class AppDelegate: NSObject, NSApplicationDelegate {

    let controller = PetController()
    private var petWindowController: PetWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-style agent: no Dock icon.
        NSApp.setActivationPolicy(.accessory)
        installAppMenu()

        let root = AnyView(PetView().environmentObject(controller))
        let windowController = PetWindowController(rootView: root)
        windowController.show()
        petWindowController = windowController

        controller.start()
    }

    /// Minimal main menu so standard shortcuts (Cmd-Q) work even as an accessory.
    private func installAppMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "退出 KeyboardPet", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }
}
