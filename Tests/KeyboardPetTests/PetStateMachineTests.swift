import XCTest
@testable import KeyboardPet

final class PetStateMachineTests: XCTestCase {

    private var settings: IsolatedSettings!

    override func setUp() {
        super.setUp()
        settings = IsolatedSettings()   // factory defaults
    }

    override func tearDown() {
        settings.restore()
        settings = nil
        super.tearDown()
    }

    private func typing(wpm: Int = 10, idle: TimeInterval = 0,
                        deleteRate: Double = 0, flowSince: Date? = nil) -> Metrics {
        var m = Metrics()
        m.wpm = wpm; m.idleSeconds = idle; m.deleteRate = deleteRate; m.flowSince = flowSince
        return m
    }

    func testActiveTypingIsTyping() {
        let sm = PetStateMachine()
        XCTAssertEqual(sm.evaluate(typing()), .typing)
    }

    func testIdleProgression() {
        let sm = PetStateMachine()
        XCTAssertEqual(sm.evaluate(typing(wpm: 0, idle: 0)), .idle)
        XCTAssertEqual(sm.evaluate(typing(wpm: 0, idle: 40)), .thinking)   // > 30
        XCTAssertEqual(sm.evaluate(typing(wpm: 0, idle: 150)), .sleepy)    // > 120
        XCTAssertEqual(sm.evaluate(typing(wpm: 0, idle: 400)), .sleeping)  // > 300
    }

    func testDeletingBeatsTyping() {
        let sm = PetStateMachine()
        XCTAssertEqual(sm.evaluate(typing(deleteRate: 0.6)), .deleting)
    }

    func testFlowRequiresSustainedWindow() {
        let sm = PetStateMachine()
        let now = Date()
        // flowSince only 5s ago — not sustained long enough (default sustain 30s).
        XCTAssertEqual(sm.evaluate(typing(flowSince: now.addingTimeInterval(-5)), now: now), .typing)
        // 31s ago — sustained → flow.
        XCTAssertEqual(sm.evaluate(typing(flowSince: now.addingTimeInterval(-31)), now: now), .flow)
    }

    func testRecordOverridesEverything() {
        let sm = PetStateMachine()
        let now = Date()
        sm.triggerRecord(now: now)
        XCTAssertEqual(sm.evaluate(typing(wpm: 0, idle: 9999), now: now), .record)
        // After the record window elapses, fall back to the real state.
        let later = now.addingTimeInterval(10)
        XCTAssertEqual(sm.evaluate(typing(wpm: 0, idle: 9999), now: later), .sleeping)
    }

    func testWakeupTriggeredFromSleeping() {
        let sm = PetStateMachine()
        let now = Date()
        XCTAssertEqual(sm.evaluate(typing(wpm: 0, idle: 400), now: now), .sleeping)
        XCTAssertEqual(sm.evaluate(typing(), now: now), .wakeup)
    }

    func testIsNightRespectsWindow() {
        // Default night window is 00:00–05:00.
        XCTAssertTrue(PetStateMachine.isNight(makeDate(year: 2026, month: 6, day: 1, hour: 2),
                                              calendar: utcCalendar))
        XCTAssertFalse(PetStateMachine.isNight(makeDate(year: 2026, month: 6, day: 1, hour: 10),
                                               calendar: utcCalendar))
    }
}
