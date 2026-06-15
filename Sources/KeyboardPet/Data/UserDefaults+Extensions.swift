import Foundation

/// Lightweight configuration persistence (window position, lifetime records,
/// XP/level). Heavyweight per-keystroke statistics live in `StatsStore`.
extension UserDefaults {

    private enum Keys {
        static let petOriginX = "pet.origin.x"
        static let petOriginY = "pet.origin.y"
        static let hasStoredOrigin = "pet.origin.stored"
        static let peakWPM = "stats.peakWPM"
        static let level = "xp.level"
        static let totalXP = "xp.total"
    }

    /// Last persisted pet-window origin, or nil if never moved.
    var petWindowOrigin: CGPoint? {
        get {
            guard bool(forKey: Keys.hasStoredOrigin) else { return nil }
            return CGPoint(x: double(forKey: Keys.petOriginX),
                           y: double(forKey: Keys.petOriginY))
        }
        set {
            if let p = newValue {
                set(p.x, forKey: Keys.petOriginX)
                set(p.y, forKey: Keys.petOriginY)
                set(true, forKey: Keys.hasStoredOrigin)
            } else {
                set(false, forKey: Keys.hasStoredOrigin)
            }
        }
    }

    var peakWPM: Int {
        get { integer(forKey: Keys.peakWPM) }
        set { set(newValue, forKey: Keys.peakWPM) }
    }

    var petLevel: Int {
        get { max(1, integer(forKey: Keys.level)) }
        set { set(newValue, forKey: Keys.level) }
    }

    var totalXP: Int {
        get { integer(forKey: Keys.totalXP) }
        set { set(newValue, forKey: Keys.totalXP) }
    }
}
