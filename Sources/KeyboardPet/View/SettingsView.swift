import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// User-facing settings for the state-machine / metrics thresholds.
/// Bound directly to `PetSettings.shared`; every edit applies live.
struct SettingsView: View {
    @ObservedObject private var settings = PetSettings.shared
    @ObservedObject private var launchAtLogin = LaunchAtLogin.shared
    @State private var showAdvanced = false
    @State private var showEraseConfirm = false

    var body: some View {
        Form {
            generalSection
            appearanceSection
            idleSection
            flowSection
            deletingSection
            nightSection
            advancedSection
            dataSection
            resetSection
        }
        .formStyle(.grouped)
        .frame(width: 470, height: 600)
        .alert("清除所有数据？", isPresented: $showEraseConfirm) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) { PetController.shared.eraseAllData() }
        } message: {
            Text("将永久删除全部击键统计、经验/等级和峰值 WPM 记录。此操作无法撤销。")
        }
    }

    // MARK: 通用

    private var generalSection: some View {
        Section {
            Toggle("登录时启动", isOn: $launchAtLogin.isEnabled)
                .disabled(!launchAtLogin.isSupported)
        } header: {
            Text("通用")
        } footer: {
            if !launchAtLogin.isSupported {
                Text("以 .app 形式运行时可用（请通过 build_app.sh 构建）。")
                    .font(.caption).foregroundStyle(.secondary)
            } else if let err = launchAtLogin.lastError {
                Text("设置失败：\(err)")
                    .font(.caption).foregroundStyle(.red)
            }
        }
    }

    // MARK: 外观

    private var appearanceSection: some View {
        Section("外观") {
            percentRow("桌面螃蟹大小", bind(\.petScale), range: 0.6...2.0)
        }
    }

    // MARK: 空闲节奏

    private var idleSection: some View {
        Section {
            durationRow("发呆 → 思考", thinkingBinding, range: 5...300)
            durationRow("思考 → 犯困", sleepyBinding, range: 10...900)
            durationRow("犯困 → 睡着", sleepingBinding, range: 20...1800)
        } header: {
            Text("空闲节奏")
        } footer: {
            Text("三个阈值会自动保持递增顺序：思考 < 犯困 < 睡着。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: 心流

    private var flowSection: some View {
        Section("心流") {
            Toggle("启用心流状态", isOn: bind(\.flowEnabled))
            intRow("WPM 阈值", bind(\.flowThreshold), range: 20...150, step: 5, suffix: " WPM")
                .disabled(!settings.flowEnabled)
            durationRow("持续时间", bind(\.flowSustain), range: 5...120)
                .disabled(!settings.flowEnabled)
        }
    }

    // MARK: 纠结

    private var deletingSection: some View {
        Section("纠结（高删除率）") {
            Toggle("启用纠结状态", isOn: bind(\.deletingEnabled))
            percentRow("删除率阈值", bind(\.deleteRateThreshold), range: 0.1...0.9)
                .disabled(!settings.deletingEnabled)
        }
    }

    // MARK: 夜间

    private var nightSection: some View {
        Section {
            Toggle("启用夜间模式（穿睡衣）", isOn: bind(\.nightEnabled))
            hourRow("开始时间", bind(\.nightStartHour))
                .disabled(!settings.nightEnabled)
            hourRow("结束时间", bind(\.nightEndHour))
                .disabled(!settings.nightEnabled)
        } header: {
            Text("夜间时段")
        } footer: {
            Text(nightSummary).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var nightSummary: String {
        let s = settings.nightStartHour, e = settings.nightEndHour
        if s == e { return "开始与结束相同，夜间模式不会触发。" }
        if s > e { return String(format: "当前：%02d:00 – 次日 %02d:00（跨午夜）", s, e) }
        return String(format: "当前：%02d:00 – %02d:00", s, e)
    }

    // MARK: 高级

    private var advancedSection: some View {
        Section {
            DisclosureGroup("高级参数", isExpanded: $showAdvanced) {
                durationRow("活跃判定（距上次按键）", bind(\.activeThreshold), range: 0.5...5, step: 0.5)
                durationRow("WPM 采样窗口", bind(\.wpmWindow), range: 3...30)
                durationRow("删除率采样窗口", bind(\.deleteWindow), range: 5...60)
                durationRow("破纪录庆祝时长", bind(\.recordDuration), range: 1...10)
                durationRow("惊醒动画时长", bind(\.wakeupDuration), range: 1...5, step: 0.5)
            }
        } footer: {
            Text("一般无需改动；除非你想微调指标灵敏度或动画时长。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: 数据

    private var dataSection: some View {
        Section {
            Button {
                exportData()
            } label: {
                Label("导出数据…", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) {
                showEraseConfirm = true
            } label: {
                Label("清除所有数据…", systemImage: "trash")
            }
        } header: {
            Text("数据")
        } footer: {
            Text("导出为 JSON（仅含聚合的逐小时击键数、经验与记录，绝不含输入内容）。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func exportData() {
        guard let data = DataExporter.makeJSON() else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "keyboardpet-data.json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }

    // MARK: 重置

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                settings.resetToDefaults()
            } label: {
                Label("恢复默认设置", systemImage: "arrow.counterclockwise")
            }
        }
    }

    // MARK: Rows

    private func durationRow(_ title: String, _ value: Binding<Double>,
                            range: ClosedRange<Double>, step: Double = 1) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(durationLabel(value.wrappedValue))
                    .monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
    }

    private func intRow(_ title: String, _ value: Binding<Int>,
                        range: ClosedRange<Int>, step: Int, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue)\(suffix)")
                    .monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: Binding(get: { Double(value.wrappedValue) },
                                  set: { value.wrappedValue = Int($0.rounded()) }),
                   in: Double(range.lowerBound)...Double(range.upperBound),
                   step: Double(step))
        }
    }

    private func percentRow(_ title: String, _ value: Binding<Double>,
                            range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded()))%")
                    .monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: 0.05)
        }
    }

    private func hourRow(_ title: String, _ value: Binding<Int>) -> some View {
        Picker(title, selection: value) {
            ForEach(0..<24, id: \.self) { h in
                Text(String(format: "%02d:00", h)).tag(h)
            }
        }
    }

    // MARK: Bindings

    /// Generic two-way binding onto a `PetSettings` property.
    private func bind<V>(_ keyPath: ReferenceWritableKeyPath<PetSettings, V>) -> Binding<V> {
        Binding(get: { settings[keyPath: keyPath] },
                set: { settings[keyPath: keyPath] = $0 })
    }

    /// Idle-threshold bindings that clamp to keep thinking < sleepy < sleeping.
    private var thinkingBinding: Binding<Double> {
        Binding(get: { settings.thinkingAfter },
                set: { settings.thinkingAfter = min($0, settings.sleepyAfter - 1) })
    }
    private var sleepyBinding: Binding<Double> {
        Binding(get: { settings.sleepyAfter },
                set: { settings.sleepyAfter = min(max($0, settings.thinkingAfter + 1),
                                                   settings.sleepingAfter - 1) })
    }
    private var sleepingBinding: Binding<Double> {
        Binding(get: { settings.sleepingAfter },
                set: { settings.sleepingAfter = max($0, settings.sleepyAfter + 1) })
    }

    // MARK: Formatting

    private func durationLabel(_ v: Double) -> String {
        if v < 60 {
            return v == v.rounded() ? "\(Int(v)) 秒" : String(format: "%.1f 秒", v)
        }
        let m = Int(v) / 60, s = Int(v) % 60
        return s == 0 ? "\(m) 分" : "\(m) 分 \(s) 秒"
    }
}
