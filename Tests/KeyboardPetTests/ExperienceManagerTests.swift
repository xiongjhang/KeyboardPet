import XCTest
@testable import KeyboardPet

final class ExperienceManagerTests: XCTestCase {

    func testXPForLevelFollowsSquaredCurve() {
        XCTAssertEqual(ExperienceManager.xpForLevel(1), 0)
        XCTAssertEqual(ExperienceManager.xpForLevel(2), 100)   // (1*10)^2
        XCTAssertEqual(ExperienceManager.xpForLevel(3), 400)   // (2*10)^2
        XCTAssertEqual(ExperienceManager.xpForLevel(4), 900)   // (3*10)^2
    }

    func testLevelForXPThresholds() {
        XCTAssertEqual(ExperienceManager.level(forXP: 0), 1)
        XCTAssertEqual(ExperienceManager.level(forXP: 99), 1)
        XCTAssertEqual(ExperienceManager.level(forXP: 100), 2)
        XCTAssertEqual(ExperienceManager.level(forXP: 399), 2)
        XCTAssertEqual(ExperienceManager.level(forXP: 400), 3)
        XCTAssertEqual(ExperienceManager.level(forXP: 899), 3)
        XCTAssertEqual(ExperienceManager.level(forXP: 900), 4)
    }

    func testNegativeXPClampsToLevelOne() {
        XCTAssertEqual(ExperienceManager.level(forXP: -50), 1)
    }

    func testLevelAndXPForLevelRoundTrip() {
        for level in 1...20 {
            let floor = ExperienceManager.xpForLevel(level)
            XCTAssertEqual(ExperienceManager.level(forXP: floor), level,
                           "XP \(floor) should land exactly on level \(level)")
        }
    }
}
