import SwiftUI

/// Statistics window: level/XP, today's totals, a GitHub-style monthly calendar
/// heatmap (with month navigation), and an hourly breakdown for the day picked
/// in that calendar.
struct StatsPanel: View {
    @EnvironmentObject var controller: PetController
    @ObservedObject private var experience = ExperienceManager.shared

    @State private var hourly: [Int: Int] = [:]
    @State private var daily: [Int: Int] = [:]
    /// First day of the month currently shown in the calendar.
    @State private var displayedMonth: Date = StatsPanel.startOfMonth(Date())
    /// "yyyy-MM-dd" the hourly breakdown drills into; nil means today.
    @State private var selectedDay: String? = nil

    private let refresh = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private let cellSize: CGFloat = 24

    // MARK: Derived — hourly

    private var maxCount: Int { max(1, hourly.values.max() ?? 1) }
    private var activeHours: Int { hourly.values.filter { $0 > 0 }.count }
    private var peakHour: Int? { hourly.max { $0.value < $1.value }?.key }
    private var effectiveDay: String { selectedDay ?? StatsStore.dayString() }

    // MARK: Derived — monthly

    private var maxDaily: Int { max(1, daily.values.max() ?? 1) }
    private var isCurrentMonth: Bool {
        Calendar.current.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }
    private var monthTitle: String {
        let c = Calendar.current.dateComponents([.year, .month], from: displayedMonth)
        return "\(c.year ?? 0) 年 \(c.month ?? 0) 月"
    }
    private var weekdaySymbols: [String] {
        let cal = Calendar.current
        let syms = cal.veryShortWeekdaySymbols      // index 0 = Sunday
        let start = cal.firstWeekday - 1
        return (0..<7).map { syms[($0 + start) % 7] }
    }
    /// Weeks as columns; each week is 7 weekday rows holding a day-of-month or nil.
    private var monthGrid: [[Int?]] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: displayedMonth)
        guard let first = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: first) else { return [] }
        let daysInMonth = range.count
        let firstWeekday = cal.component(.weekday, from: first)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        let weekCount = Int(ceil(Double(leading + daysInMonth) / 7.0))
        var grid = Array(repeating: Array<Int?>(repeating: nil, count: 7), count: weekCount)
        for day in 1...daysInMonth {
            let pos = leading + (day - 1)
            grid[pos / 7][pos % 7] = day
        }
        return grid
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            statsRow
            monthlyHeatmap
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

    // MARK: Monthly calendar heatmap

    private var monthlyHeatmap: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("活动日历（按日）").font(.subheadline).bold()
                Spacer()
                Button { changeMonth(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.borderless)
                Text(monthTitle).font(.caption).monospacedDigit().frame(minWidth: 84)
                Button { changeMonth(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.borderless)
                    .disabled(isCurrentMonth)
            }

            HStack(alignment: .top, spacing: 4) {
                VStack(spacing: 4) {
                    ForEach(weekdaySymbols.indices, id: \.self) { i in
                        Text(weekdaySymbols[i])
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, height: cellSize)
                    }
                }
                ForEach(Array(monthGrid.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { row in
                            dayCell(week[row])
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Text("点击某日查看当天的小时分布")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func dayCell(_ day: Int?) -> some View {
        Group {
            if let day {
                let ds = dayString(day)
                let count = daily[day] ?? 0
                RoundedRectangle(cornerRadius: 4)
                    .fill(cellColor(count: count, max: maxDaily))
                    .frame(maxWidth: .infinity)
                    .frame(height: cellSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(borderColor(for: ds), lineWidth: borderWidth(for: ds))
                    )
                    .overlay(
                        Text("\(day)")
                            .font(.system(size: 11))
                            .foregroundStyle(count > 0 ? Color.white.opacity(0.9) : Color.secondary)
                    )
                    .help("\(monthTitle) \(day) 日 — \(count) 击键")
                    .contentShape(Rectangle())
                    .onTapGesture { selectedDay = ds; reload() }
            } else {
                Color.clear.frame(maxWidth: .infinity).frame(height: cellSize)
            }
        }
    }

    private func borderColor(for ds: String) -> Color {
        if ds == effectiveDay { return Color.green.opacity(0.95) }
        if ds == StatsStore.dayString() { return Color.green.opacity(0.45) }
        return Color.primary.opacity(0.08)
    }

    private func borderWidth(for ds: String) -> CGFloat {
        ds == effectiveDay ? 2 : 1
    }

    // MARK: Hourly heatmap (for the selected day)

    private var hourlyTitle: String {
        if effectiveDay == StatsStore.dayString() { return "今日活动分布（按小时）" }
        let parts = effectiveDay.split(separator: "-")
        if parts.count == 3 {
            return "\(Int(parts[1]) ?? 0) 月 \(Int(parts[2]) ?? 0) 日活动分布（按小时）"
        }
        return "活动分布（按小时）"
    }

    private var heatmap: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(hourlyTitle).font(.subheadline).bold()
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
                        .fill(cellColor(count: count, max: maxCount))
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

    // MARK: Helpers

    private func cellColor(count: Int, max maxCount: Int) -> Color {
        guard count > 0 else { return Color.primary.opacity(0.06) }
        let intensity = 0.25 + 0.75 * Double(count) / Double(max(1, maxCount))
        let base = Color(red: 0.18, green: 0.72, blue: 0.40)
        return base.opacity(intensity)
    }

    private func dayString(_ day: Int) -> String {
        let c = Calendar.current.dateComponents([.year, .month], from: displayedMonth)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, day)
    }

    private func changeMonth(_ delta: Int) {
        guard let d = Calendar.current.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        displayedMonth = StatsPanel.startOfMonth(d)
        reload()
    }

    private static func startOfMonth(_ date: Date) -> Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }

    private func reload() {
        hourly = StatsStore.shared.hourlyCounts(forDay: effectiveDay)
        daily = StatsStore.shared.dailyCounts(forMonth: StatsStore.monthString(displayedMonth))
    }
}
