import SwiftUI

/// Daily statistics window: level/XP, today's totals, and an hourly heatmap.
struct StatsPanel: View {
    @EnvironmentObject var controller: PetController
    @ObservedObject private var experience = ExperienceManager.shared

    @State private var hourly: [Int: Int] = [:]
    private let refresh = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private var maxCount: Int { max(1, hourly.values.max() ?? 1) }
    private var activeHours: Int { hourly.values.filter { $0 > 0 }.count }
    private var peakHour: Int? { hourly.max { $0.value < $1.value }?.key }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            statsRow
            heatmap
        }
        .padding(22)
        .frame(width: 460)
        .onAppear(perform: reload)
        .onReceive(refresh) { _ in reload() }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(controller.state.emoji).font(.system(size: 34))
                VStack(alignment: .leading, spacing: 2) {
                    Text("KeyboardPet").font(.headline)
                    Text("Lv.\(experience.level) · \(controller.state.displayName)")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }
            ProgressView(value: experience.levelProgress) {
                HStack {
                    Text("升级进度").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("还需 \(experience.xpToNextLevel) XP 到 Lv.\(experience.level + 1)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .tint(.green)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(title: "今日击键", value: "\(controller.snapshot.todayKeystrokes)", system: "keyboard")
            statCard(title: "活跃小时", value: "\(activeHours)", system: "clock")
            statCard(title: "峰值 WPM", value: "\(controller.snapshot.peakWPM)", system: "bolt.fill")
        }
    }

    private func statCard(title: String, value: String, system: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: system).font(.system(size: 16)).foregroundStyle(.green)
            Text(value).font(.title2).bold().monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private var heatmap: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("今日活动分布（按小时）").font(.subheadline).bold()
                Spacer()
                if let peak = peakHour, (hourly[peak] ?? 0) > 0 {
                    Text("最活跃：\(String(format: "%02d:00", peak))")
                        .font(.caption).foregroundStyle(.green)
                }
            }

            HStack(spacing: 3) {
                ForEach(0..<24, id: \.self) { hour in
                    let count = hourly[hour] ?? 0
                    RoundedRectangle(cornerRadius: 3)
                        .fill(cellColor(count: count, isPeak: hour == peakHour && count > 0))
                        .frame(height: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                        .help("\(String(format: "%02d:00", hour)) — \(count) 击键")
                }
            }

            HStack {
                Text("00:00").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("12:00").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("23:00").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func cellColor(count: Int, isPeak: Bool) -> Color {
        guard count > 0 else { return Color.primary.opacity(0.06) }
        let intensity = 0.25 + 0.75 * Double(count) / Double(maxCount)
        let base = Color(red: 0.18, green: 0.72, blue: 0.40)
        return base.opacity(intensity)
    }

    private func reload() {
        hourly = StatsStore.shared.hourlyCounts(forDay: StatsStore.dayString())
    }
}
