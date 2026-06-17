import Foundation

/// Builds a portable JSON snapshot of all locally stored data so users can back
/// it up or inspect exactly what KeyboardPet keeps (which is only aggregate
/// counts — never characters).
enum DataExporter {

    struct Payload: Codable {
        let schemaVersion: Int
        let exportedAt: Date
        let totalXP: Int
        let level: Int
        let peakWPM: Int
        let hourly: [HourlyEntry]
    }

    struct HourlyEntry: Codable {
        let day: String   // "yyyy-MM-dd"
        let hour: Int     // 0...23
        let count: Int
    }

    static func makeJSON() -> Data? {
        let hourly = StatsStore.shared.allHourly()
            .map { HourlyEntry(day: $0.day, hour: $0.hour, count: $0.count) }
            .sorted { ($0.day, $0.hour) < ($1.day, $1.hour) }

        let payload = Payload(
            schemaVersion: 1,
            exportedAt: Date(),
            totalXP: UserDefaults.standard.totalXP,
            level: UserDefaults.standard.petLevel,
            peakWPM: UserDefaults.standard.peakWPM,
            hourly: hourly
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(payload)
    }
}
