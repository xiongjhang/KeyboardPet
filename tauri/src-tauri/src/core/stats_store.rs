//! Persists per-hour keystroke counts. Ported from the Swift `StatsStore`
//! (which used SwiftData); here we keep a flat map and persist it as JSON in the
//! app data directory. Writes are batched by the runtime to honor the
//! performance budget.

use std::collections::BTreeMap;
use std::path::PathBuf;

use chrono::{DateTime, Datelike, Local, Timelike};
use serde::{Deserialize, Serialize};

/// Day string `"yyyy-MM-dd"` for an instant in the local calendar.
pub fn day_string(date: DateTime<Local>) -> String {
    format!("{:04}-{:02}-{:02}", date.year(), date.month(), date.day())
}

/// Month string `"yyyy-MM"`.
pub fn month_string(date: DateTime<Local>) -> String {
    format!("{:04}-{:02}", date.year(), date.month())
}

/// Hour of day (0..=23) in the local calendar.
pub fn hour_of(date: DateTime<Local>) -> u32 {
    date.hour()
}

#[derive(Default, Serialize, Deserialize)]
struct StoreData {
    /// "yyyy-MM-dd-HH" → keystroke count.
    counts: BTreeMap<String, i64>,
}

pub struct StatsStore {
    data: StoreData,
    path: Option<PathBuf>,
}

impl StatsStore {
    /// Load from `path` (created lazily on first save). Pass `None` for an
    /// in-memory store (tests).
    pub fn load(path: Option<PathBuf>) -> Self {
        let data = path
            .as_ref()
            .and_then(|p| std::fs::read_to_string(p).ok())
            .and_then(|s| serde_json::from_str::<StoreData>(&s).ok())
            .unwrap_or_default();
        Self { data, path }
    }

    fn key(day: &str, hour: u32) -> String {
        format!("{}-{:02}", day, hour)
    }

    /// Add `count` keystrokes to the (day, hour) bucket.
    pub fn add(&mut self, count: i64, day: &str, hour: u32) {
        if count <= 0 {
            return;
        }
        *self.data.counts.entry(Self::key(day, hour)).or_insert(0) += count;
    }

    /// Hour → keystroke count for the given day (hours with 0 omitted).
    pub fn hourly_counts(&self, day: &str) -> BTreeMap<u32, i64> {
        let prefix = format!("{}-", day);
        let mut result = BTreeMap::new();
        for (k, v) in &self.data.counts {
            if let Some(hh) = k.strip_prefix(&prefix) {
                if let Ok(hour) = hh.parse::<u32>() {
                    result.insert(hour, *v);
                }
            }
        }
        result
    }

    /// Day-of-month → keystroke count for the given month "yyyy-MM"
    /// (days with 0 omitted). Aggregates every hour bucket in that month.
    pub fn daily_counts(&self, month: &str) -> BTreeMap<u32, i64> {
        let prefix = format!("{}-", month);
        let mut result: BTreeMap<u32, i64> = BTreeMap::new();
        for (k, v) in &self.data.counts {
            // key = "yyyy-MM-dd-HH"; match month prefix, take the dd segment.
            if let Some(rest) = k.strip_prefix(&prefix) {
                // rest = "dd-HH"
                if let Some((dd, _hh)) = rest.split_once('-') {
                    if let Ok(day) = dd.parse::<u32>() {
                        *result.entry(day).or_insert(0) += v;
                    }
                }
            }
        }
        result
    }

    /// Every stored (day, hour, count) row — used for data export.
    pub fn all_hourly(&self) -> Vec<(String, u32, i64)> {
        self.data
            .counts
            .iter()
            .filter_map(|(k, v)| {
                // k = "yyyy-MM-dd-HH"
                let idx = k.rfind('-')?;
                let day = k[..idx].to_string();
                let hour = k[idx + 1..].parse::<u32>().ok()?;
                Some((day, hour, *v))
            })
            .collect()
    }

    /// Permanently delete every stored keystroke bucket.
    pub fn erase_all(&mut self) {
        self.data.counts.clear();
        self.save();
    }

    /// Write the store to disk (no-op for an in-memory store).
    pub fn save(&self) {
        if let Some(path) = &self.path {
            if let Some(parent) = path.parent() {
                let _ = std::fs::create_dir_all(parent);
            }
            if let Ok(json) = serde_json::to_string(&self.data) {
                let _ = std::fs::write(path, json);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hourly_and_daily_aggregation() {
        let mut s = StatsStore::load(None);
        s.add(5, "2026-06-18", 9);
        s.add(3, "2026-06-18", 9); // same bucket accumulates
        s.add(7, "2026-06-18", 14);
        s.add(2, "2026-06-20", 10);

        let hourly = s.hourly_counts("2026-06-18");
        assert_eq!(hourly.get(&9), Some(&8));
        assert_eq!(hourly.get(&14), Some(&7));
        assert_eq!(hourly.get(&10), None);

        let daily = s.daily_counts("2026-06");
        assert_eq!(daily.get(&18), Some(&15)); // 8 + 7
        assert_eq!(daily.get(&20), Some(&2));
    }

    #[test]
    fn add_ignores_nonpositive_and_erase_clears() {
        let mut s = StatsStore::load(None);
        s.add(0, "2026-06-18", 9);
        s.add(-4, "2026-06-18", 9);
        assert!(s.hourly_counts("2026-06-18").is_empty());
        s.add(4, "2026-06-18", 9);
        assert_eq!(s.all_hourly().len(), 1);
        s.erase_all();
        assert!(s.all_hourly().is_empty());
    }
}
