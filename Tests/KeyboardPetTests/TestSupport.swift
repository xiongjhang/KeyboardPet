import Foundation
@testable import KeyboardPet

/// Swaps `PetSettings.shared` for an instance backed by a throwaway
/// `UserDefaults` suite so tests run against factory defaults regardless of the
/// developer's real settings. Call `restore()` in tearDown.
final class IsolatedSettings {
    private let previous: PetSettings
    private let suiteName: String
    let defaults: UserDefaults

    init() {
        previous = PetSettings.shared
        suiteName = "KeyboardPetTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        PetSettings.shared = PetSettings(defaults: defaults)
    }

    func restore() {
        PetSettings.shared = previous
        defaults.removePersistentDomain(forName: suiteName)
    }
}

/// A UTC Gregorian calendar so date-string tests are timezone-independent.
let utcCalendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

func makeDate(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
    var comps = DateComponents()
    comps.year = year; comps.month = month; comps.day = day; comps.hour = hour
    return utcCalendar.date(from: comps)!
}
