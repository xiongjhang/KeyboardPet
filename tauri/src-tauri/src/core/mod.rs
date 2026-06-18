//! Platform-independent domain logic, ported 1:1 from the macOS Swift app.
//!
//! Nothing in this module touches the OS, the window, or the keyboard hook — it
//! only turns a stream of `KeyEvent`s into `Metrics`, a `PetState`, and XP. The
//! behavior baseline (thresholds, formulas, priority order) is documented in
//! `docs/cross-platform-plan.md` and locked down by the unit tests in each file.

pub mod experience;
pub mod key_event;
pub mod metrics;
pub mod settings;
pub mod state_machine;

pub use experience::ExperienceManager;
pub use key_event::KeyEvent;
pub use metrics::{Metrics, MetricsEngine};
pub use settings::Settings;
pub use state_machine::{PetState, PetStateMachine};
