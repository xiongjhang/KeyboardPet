import XCTest
@testable import KeyboardPet

final class StatsDateTests: XCTestCase {

    func testDayStringIsZeroPadded() {
        let date = makeDate(year: 2026, month: 6, day: 7)
        XCTAssertEqual(StatsStore.dayString(date, calendar: utcCalendar), "2026-06-07")
    }

    func testMonthStringIsZeroPadded() {
        let date = makeDate(year: 2026, month: 1, day: 31)
        XCTAssertEqual(StatsStore.monthString(date, calendar: utcCalendar), "2026-01")
    }

    func testDayAndMonthStringAgreeOnPrefix() {
        let date = makeDate(year: 2025, month: 12, day: 25)
        let day = StatsStore.dayString(date, calendar: utcCalendar)
        let month = StatsStore.monthString(date, calendar: utcCalendar)
        XCTAssertTrue(day.hasPrefix(month + "-"),
                      "\(day) should begin with month prefix \(month)-")
    }
}
