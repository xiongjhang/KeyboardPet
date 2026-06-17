import Foundation
import SwiftData

/// One hour's keystroke total for a given day.
@Model
final class HourStat {
    /// "yyyy-MM-dd-HH" — unique per day+hour.
    @Attribute(.unique) var key: String
    var day: String       // "yyyy-MM-dd"
    var hour: Int         // 0 ... 23
    var count: Int

    init(key: String, day: String, hour: Int, count: Int) {
        self.key = key
        self.day = day
        self.hour = hour
        self.count = count
    }
}

/// Persists per-hour keystroke counts (SwiftData). Writes are batched by the
/// controller (every 60s) to honor the performance budget.
final class StatsStore {

    static let shared = StatsStore()

    private let container: ModelContainer
    private let context: ModelContext

    init() {
        do {
            let schema = Schema([HourStat.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: config)
            context = ModelContext(container)
        } catch {
            // Fall back to in-memory so the app still runs if the store is corrupt.
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: HourStat.self, configurations: config)
            context = ModelContext(container)
        }
    }

    static func dayString(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func monthString(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    /// Add `count` keystrokes to the (day, hour) bucket.
    func add(count: Int, day: String, hour: Int) {
        guard count > 0 else { return }
        let key = "\(day)-\(String(format: "%02d", hour))"
        let descriptor = FetchDescriptor<HourStat>(predicate: #Predicate { $0.key == key })
        if let existing = try? context.fetch(descriptor).first {
            existing.count += count
        } else {
            context.insert(HourStat(key: key, day: day, hour: hour, count: count))
        }
        try? context.save()
    }

    /// Hour → keystroke count for the given day (hours with 0 omitted).
    func hourlyCounts(forDay day: String) -> [Int: Int] {
        let descriptor = FetchDescriptor<HourStat>(predicate: #Predicate { $0.day == day })
        let rows = (try? context.fetch(descriptor)) ?? []
        var result: [Int: Int] = [:]
        for row in rows { result[row.hour] = row.count }
        return result
    }

    /// Every stored (day, hour, count) row — used for data export.
    func allHourly() -> [(day: String, hour: Int, count: Int)] {
        let rows = (try? context.fetch(FetchDescriptor<HourStat>())) ?? []
        return rows.map { ($0.day, $0.hour, $0.count) }
    }

    /// Permanently delete every stored keystroke bucket.
    func eraseAll() {
        try? context.delete(model: HourStat.self)
        try? context.save()
    }

    /// Day-of-month → keystroke count for the given month "yyyy-MM"
    /// (days with 0 omitted). Aggregates every hour bucket in that month.
    func dailyCounts(forMonth month: String) -> [Int: Int] {
        let prefix = month + "-"
        let descriptor = FetchDescriptor<HourStat>(predicate: #Predicate { $0.day.starts(with: prefix) })
        let rows = (try? context.fetch(descriptor)) ?? []
        var result: [Int: Int] = [:]
        for row in rows {
            let day = Int(row.day.suffix(2)) ?? 0
            result[day, default: 0] += row.count
        }
        return result
    }
}
