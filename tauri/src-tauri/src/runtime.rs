//! Wires the keyboard hook into the core engines and pushes live updates to the
//! frontend.
//!
//! Data flow: key press → `MetricsEngine` (+ XP) → a 0.5s ticker recomputes
//! metrics, runs the `PetStateMachine`, and emits a `pet-update` event that the
//! pet window renders. This is the cross-platform analogue of the Swift
//! `PetController`.

use std::sync::{Arc, Mutex};
use std::time::Duration;

use chrono::{Local, Utc};
use serde::Serialize;
use tauri::{AppHandle, Emitter};

use crate::core::{ExperienceManager, MetricsEngine, PetStateMachine, Settings};
use crate::platform;

/// Owns the live engines; shared between the keyboard thread and the ticker.
struct PetRuntime {
    metrics: MetricsEngine,
    machine: PetStateMachine,
    xp: ExperienceManager,
    settings: Settings,
}

impl PetRuntime {
    fn new(settings: Settings) -> Self {
        Self {
            metrics: MetricsEngine::new(settings.clone(), 0, 0),
            machine: PetStateMachine::new(settings.clone()),
            xp: ExperienceManager::new(0),
            settings,
        }
    }
}

/// Snapshot pushed to the pet window on every tick.
#[derive(Serialize, Clone)]
struct PetUpdate {
    state: String,
    display_name: String,
    emoji: String,
    is_night: bool,
    wpm: i64,
    peak_wpm: i64,
    today_keystrokes: i64,
    delete_rate: f64,
    level: i64,
    level_progress: f64,
    xp_to_next: i64,
}

/// Start keyboard monitoring and the state ticker. Call once from `setup`.
pub fn launch(app: &AppHandle) {
    // macOS: the listener needs Accessibility permission. This prompts on first
    // run and registers the app under System Settings ▸ Privacy & Security.
    #[cfg(target_os = "macos")]
    {
        let trusted =
            macos_accessibility_client::accessibility::application_is_trusted_with_prompt();
        if !trusted {
            eprintln!(
                "[keyboard] Accessibility not granted yet — enable KeyboardPet under \
                 System Settings ▸ Privacy & Security ▸ Accessibility, then relaunch."
            );
        }
    }

    let runtime = Arc::new(Mutex::new(PetRuntime::new(Settings::default())));

    // Keyboard → metrics + XP. A broken record arms the celebratory state.
    let kb_rt = runtime.clone();
    platform::keyboard::start_listener(move |event| {
        let now = event.timestamp;
        let mut rt = kb_rt.lock().unwrap();
        let broke_record = rt.metrics.ingest(event);
        rt.xp.award(1);
        if broke_record.is_some() {
            rt.machine.trigger_record(now);
        }
    });

    // 0.5s ticker → recompute, evaluate state, emit to the frontend.
    let tick_rt = runtime.clone();
    let handle = app.clone();
    std::thread::spawn(move || loop {
        std::thread::sleep(Duration::from_millis(500));
        let now = Utc::now();

        let update = {
            let mut rt = tick_rt.lock().unwrap();
            if rt.metrics.tick(now).is_some() {
                rt.machine.trigger_record(now);
            }
            let m = rt.metrics.metrics.clone();
            let state = rt.machine.evaluate(&m, now);
            let is_night = PetStateMachine::is_night(Local::now(), &rt.settings);
            PetUpdate {
                state: state.as_str().to_string(),
                display_name: state.display_name().to_string(),
                emoji: state.emoji().to_string(),
                is_night,
                wpm: m.wpm,
                peak_wpm: m.peak_wpm,
                today_keystrokes: m.today_keystrokes,
                delete_rate: m.delete_rate,
                level: rt.xp.level(),
                level_progress: rt.xp.level_progress(),
                xp_to_next: rt.xp.xp_to_next_level(),
            }
        };

        let _ = handle.emit("pet-update", update);
    });
}
