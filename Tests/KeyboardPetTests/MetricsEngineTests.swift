import XCTest
@testable import KeyboardPet

final class MetricsEngineTests: XCTestCase {

    private var settings: IsolatedSettings!

    override func setUp() {
        super.setUp()
        settings = IsolatedSettings()   // factory defaults: wpmWindow 10s, deleteWindow 20s
    }

    override func tearDown() {
        settings.restore()
        settings = nil
        super.tearDown()
    }

    private func key(_ date: Date, delete: Bool = false) -> KeyEvent {
        KeyEvent(keyCode: 0, isDelete: delete, timestamp: date)
    }

    /// Regression guard for the historical "WPM unit" bug: WPM must be the
    /// 5-chars-per-word normalised value, not raw keystrokes/min.
    func testWPMUsesFiveCharactersPerWord() {
        let engine = MetricsEngine()
        let now = Date()
        // 50 keystrokes inside the 10s window → 300 chars/min → 60 WPM.
        for _ in 0..<50 { engine.ingest(key(now)) }
        XCTAssertEqual(engine.metrics.wpm, 60)
        XCTAssertEqual(engine.metrics.todayKeystrokes, 50)
    }

    func testDeleteRateIsFractionOfRecentEvents() {
        let engine = MetricsEngine()
        let now = Date()
        for _ in 0..<6 { engine.ingest(key(now)) }
        for _ in 0..<4 { engine.ingest(key(now, delete: true)) }
        XCTAssertEqual(engine.metrics.deleteRate, 0.4, accuracy: 0.0001)
    }

    func testResetDailyClearsTodayCounter() {
        let engine = MetricsEngine(initialTodayKeystrokes: 0)
        let now = Date()
        for _ in 0..<10 { engine.ingest(key(now)) }
        XCTAssertEqual(engine.metrics.todayKeystrokes, 10)
        engine.resetDaily()
        XCTAssertEqual(engine.metrics.todayKeystrokes, 0)
    }

    func testNewRecordCallbackFiresAbovePreviousPeak() {
        let engine = MetricsEngine(initialPeakWPM: 10)
        var reported: Int?
        engine.onNewRecord = { reported = $0 }
        let now = Date()
        // 50 keystrokes/10s → 60 WPM, beating the seeded peak of 10.
        for _ in 0..<50 { engine.ingest(key(now)) }
        XCTAssertEqual(reported, 60)
        XCTAssertEqual(engine.metrics.peakWPM, 60)
    }
}
