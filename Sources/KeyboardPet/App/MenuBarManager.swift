import SwiftUI
import AppKit

/// Content of the menu-bar dropdown: a live status summary + quick actions.
struct MenuBarContent: View {
    @EnvironmentObject var controller: PetController
    @ObservedObject private var experience = ExperienceManager.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let m = controller.snapshot

        Text("KeyboardPet \(controller.state.emoji) \(controller.state.displayName)")
        Text("Lv.\(experience.level) · 还需 \(experience.xpToNextLevel) XP 升级")

        Divider()

        Text("今日击键：\(m.todayKeystrokes)")
        Text("当前 WPM：\(m.wpm)")
        Text("峰值 WPM：\(m.peakWPM)")
        if controller.isNight {
            Text("🌙 夜深了，注意休息")
        }

        Divider()

        Button("打开统计面板…") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "stats")
        }
        .keyboardShortcut("s")

        Button("设置…") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",")

        if !controller.permissionGranted {
            Button("⚠️ 打开辅助功能设置…") { openAccessibilitySettings() }
        }

        Divider()

        Text("KeyboardPet \(Self.appVersion)")
        Button("在 GitHub 上查看项目…") { openProjectPage() }

        Button("退出 KeyboardPet") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    /// "v1.2.3 (45)" from the bundle, or "dev" when run unbundled (`swift run`).
    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        guard let short = info?["CFBundleShortVersionString"] as? String else { return "dev" }
        let build = info?["CFBundleVersion"] as? String
        return build.map { "v\(short) (\($0))" } ?? "v\(short)"
    }

    private func openProjectPage() {
        if let url = URL(string: "https://github.com/xiongjhang/KeyboardPet") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openAccessibilitySettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
