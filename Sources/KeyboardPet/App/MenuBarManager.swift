import SwiftUI
import AppKit

/// Content of the menu-bar dropdown: a live status summary + quick actions.
struct MenuBarContent: View {
    @EnvironmentObject var controller: PetController

    var body: some View {
        let m = controller.snapshot

        Text("KeyboardPet \(controller.state.emoji) \(controller.state.displayName)")

        Divider()

        Text("今日击键：\(m.todayKeystrokes)")
        Text("当前 WPM：\(m.wpm)")
        Text("峰值 WPM：\(m.peakWPM)")
        if controller.isNight {
            Text("🌙 夜深了，注意休息")
        }

        Divider()

        if !controller.permissionGranted {
            Button("⚠️ 打开辅助功能设置…") { openAccessibilitySettings() }
        }

        Button("退出 KeyboardPet") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func openAccessibilitySettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
