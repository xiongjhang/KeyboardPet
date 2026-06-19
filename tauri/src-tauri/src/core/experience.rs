//! Tracks lifetime XP earned from keystrokes and derives the pet's level.
//!
//! Ported from `ExperienceManager`. Level curve: level L starts at
//! `((L-1) * 10)^2` XP, so 100 → L2, 400 → L3, 900 → L4, … (sqrt growth).
//! Persistence is added in a later milestone; for now XP lives in memory.

const XP_PER_KEYSTROKE: i64 = 1;

#[derive(Debug, Clone)]
pub struct ExperienceManager {
    total_xp: i64,
    level: i64,
}

impl ExperienceManager {
    pub fn new(initial_xp: i64) -> Self {
        Self {
            total_xp: initial_xp,
            level: Self::level_for_xp(initial_xp),
        }
    }

    pub fn total_xp(&self) -> i64 {
        self.total_xp
    }

    pub fn level(&self) -> i64 {
        self.level
    }

    /// Award XP for a batch of keystrokes. Returns true if the pet leveled up.
    pub fn award(&mut self, keystrokes: i64) -> bool {
        if keystrokes <= 0 {
            return false;
        }
        let old_level = self.level;
        self.total_xp += keystrokes * XP_PER_KEYSTROKE;
        self.level = Self::level_for_xp(self.total_xp);
        self.level > old_level
    }

    /// Erase all earned XP, dropping back to level 1.
    pub fn reset(&mut self) {
        self.total_xp = 0;
        self.level = 1;
    }

    /// Progress through the current level, 0.0 ..= 1.0.
    pub fn level_progress(&self) -> f64 {
        let floor = Self::xp_for_level(self.level);
        let ceil = Self::xp_for_level(self.level + 1);
        if ceil <= floor {
            return 0.0;
        }
        (((self.total_xp - floor) as f64) / ((ceil - floor) as f64)).clamp(0.0, 1.0)
    }

    /// XP remaining until the next level.
    pub fn xp_to_next_level(&self) -> i64 {
        (Self::xp_for_level(self.level + 1) - self.total_xp).max(0)
    }

    pub fn level_for_xp(xp: i64) -> i64 {
        ((xp.max(0) as f64).sqrt() / 10.0) as i64 + 1
    }

    pub fn xp_for_level(level: i64) -> i64 {
        let base = (level - 1) * 10;
        base * base
    }
}

#[cfg(test)]
mod tests {
    use super::ExperienceManager as XP;

    #[test]
    fn xp_for_level_follows_squared_curve() {
        assert_eq!(XP::xp_for_level(1), 0);
        assert_eq!(XP::xp_for_level(2), 100); // (1*10)^2
        assert_eq!(XP::xp_for_level(3), 400); // (2*10)^2
        assert_eq!(XP::xp_for_level(4), 900); // (3*10)^2
    }

    #[test]
    fn level_for_xp_thresholds() {
        assert_eq!(XP::level_for_xp(0), 1);
        assert_eq!(XP::level_for_xp(99), 1);
        assert_eq!(XP::level_for_xp(100), 2);
        assert_eq!(XP::level_for_xp(399), 2);
        assert_eq!(XP::level_for_xp(400), 3);
        assert_eq!(XP::level_for_xp(899), 3);
        assert_eq!(XP::level_for_xp(900), 4);
    }

    #[test]
    fn negative_xp_clamps_to_level_one() {
        assert_eq!(XP::level_for_xp(-50), 1);
    }

    #[test]
    fn level_and_xp_for_level_round_trip() {
        for level in 1..=20 {
            let floor = XP::xp_for_level(level);
            assert_eq!(
                XP::level_for_xp(floor),
                level,
                "XP {} should land exactly on level {}",
                floor,
                level
            );
        }
    }

    #[test]
    fn award_levels_up_and_reset_returns_to_one() {
        let mut xp = XP::new(0);
        assert_eq!(xp.level(), 1);
        assert!(!xp.award(99)); // still L1
        assert!(xp.award(1)); // crosses 100 → L2
        assert_eq!(xp.level(), 2);
        xp.reset();
        assert_eq!(xp.level(), 1);
        assert_eq!(xp.total_xp(), 0);
    }
}
