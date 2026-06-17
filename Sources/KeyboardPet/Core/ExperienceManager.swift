import Foundation
import Combine

/// Tracks lifetime XP earned from keystrokes and derives the pet's level.
///
/// Level curve: level L starts at `((L-1) * 10)^2` XP, so 100 XP → L2,
/// 400 → L3, 900 → L4, … (sqrt growth — comfortable for thousands of
/// keystrokes per day).
final class ExperienceManager: ObservableObject {

    static let shared = ExperienceManager()

    @Published private(set) var totalXP: Int
    @Published private(set) var level: Int

    /// XP awarded per keystroke.
    private let xpPerKeystroke = 1

    init() {
        let xp = UserDefaults.standard.totalXP
        totalXP = xp
        level = ExperienceManager.level(forXP: xp)
    }

    /// Award XP for a batch of keystrokes. Returns true if the pet leveled up.
    @discardableResult
    func award(keystrokes: Int) -> Bool {
        guard keystrokes > 0 else { return false }
        let oldLevel = level
        totalXP += keystrokes * xpPerKeystroke
        level = ExperienceManager.level(forXP: totalXP)
        UserDefaults.standard.totalXP = totalXP
        UserDefaults.standard.petLevel = level
        return level > oldLevel
    }

    /// Erase all earned XP, dropping back to level 1.
    func reset() {
        totalXP = 0
        level = 1
        UserDefaults.standard.totalXP = 0
        UserDefaults.standard.petLevel = 1
    }

    /// Progress through the current level, 0.0 ... 1.0.
    var levelProgress: Double {
        let floor = ExperienceManager.xpForLevel(level)
        let ceil = ExperienceManager.xpForLevel(level + 1)
        guard ceil > floor else { return 0 }
        return min(1, max(0, Double(totalXP - floor) / Double(ceil - floor)))
    }

    /// XP remaining until the next level.
    var xpToNextLevel: Int {
        max(0, ExperienceManager.xpForLevel(level + 1) - totalXP)
    }

    static func level(forXP xp: Int) -> Int {
        Int(Double(max(0, xp)).squareRoot() / 10) + 1
    }

    static func xpForLevel(_ level: Int) -> Int {
        let base = (level - 1) * 10
        return base * base
    }
}
