pub mod commands;
pub mod core;
pub mod persist;
pub mod platform;
pub mod runtime;

use std::sync::Arc;

use tauri::{
    menu::{Menu, MenuItem, PredefinedMenuItem},
    tray::TrayIconBuilder,
    Manager, WebviewUrl, WebviewWindow, WebviewWindowBuilder,
};

use crate::runtime::AppState;

/// Move the pet window to the bottom-right corner of the primary monitor,
/// mirroring the macOS app's default placement (first run only).
fn place_bottom_right(window: &WebviewWindow) {
    if let Ok(Some(monitor)) = window.current_monitor() {
        let screen = monitor.size();
        if let Ok(win) = window.outer_size() {
            let margin = 24.0 * monitor.scale_factor();
            let x = screen.width as f64 - win.width as f64 - margin;
            let y = screen.height as f64 - win.height as f64 - margin * 4.0;
            let _ = window.set_position(tauri::PhysicalPosition::new(x, y));
        }
    }
}

/// Whether a saved window-state file already exists (the window-state plugin
/// will have restored the position, so we must not override it).
fn has_saved_window_state(app: &tauri::AppHandle) -> bool {
    app.path()
        .app_config_dir()
        .map(|dir| dir.join(".window-state.json").exists())
        .unwrap_or(false)
}

/// Open (or focus, if already open) an auxiliary window.
fn open_window(app: &tauri::AppHandle, label: &str, url: &str, title: &str, w: f64, h: f64) {
    if let Some(win) = app.get_webview_window(label) {
        let _ = win.show();
        let _ = win.set_focus();
        return;
    }
    let _ = WebviewWindowBuilder::new(app, label, WebviewUrl::App(url.into()))
        .title(title)
        .inner_size(w, h)
        .resizable(true)
        .build();
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_window_state::Builder::default().build())
        .plugin(tauri_plugin_autostart::init(
            tauri_plugin_autostart::MacosLauncher::LaunchAgent,
            None,
        ))
        .invoke_handler(tauri::generate_handler![
            commands::get_summary,
            commands::hourly_counts,
            commands::daily_counts,
            commands::get_settings,
            commands::update_settings,
            commands::get_autostart,
            commands::set_autostart,
            commands::export_data,
            commands::erase_all,
        ])
        .setup(|app| {
            // macOS: run as a menu-bar agent with no Dock icon.
            #[cfg(target_os = "macos")]
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);

            // Tray icon + menu.
            let toggle = MenuItem::with_id(app, "toggle", "显示/隐藏宠物", true, None::<&str>)?;
            let stats = MenuItem::with_id(app, "stats", "统计面板…", true, None::<&str>)?;
            let settings = MenuItem::with_id(app, "settings", "设置…", true, None::<&str>)?;
            let sep = PredefinedMenuItem::separator(app)?;
            let quit = MenuItem::with_id(app, "quit", "退出 KeyboardPet", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&toggle, &stats, &settings, &sep, &quit])?;

            TrayIconBuilder::with_id("main")
                .icon(app.default_window_icon().unwrap().clone())
                .tooltip("KeyboardPet")
                .menu(&menu)
                .show_menu_on_left_click(false)
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "quit" => {
                        use tauri_plugin_window_state::{AppHandleExt, StateFlags};
                        let _ = app.save_window_state(StateFlags::all());
                        if let Some(state) = app.try_state::<Arc<AppState>>() {
                            state.save_profile_now();
                            state.save_settings_now();
                        }
                        app.exit(0);
                    }
                    "toggle" => {
                        if let Some(w) = app.get_webview_window("pet") {
                            let visible = w.is_visible().unwrap_or(false);
                            let _ = if visible { w.hide() } else { w.show() };
                        }
                    }
                    "stats" => {
                        open_window(app, "stats", "stats.html", "KeyboardPet 统计", 520.0, 600.0)
                    }
                    "settings" => open_window(
                        app,
                        "settings",
                        "settings.html",
                        "KeyboardPet 设置",
                        460.0,
                        640.0,
                    ),
                    _ => {}
                })
                .build(app)?;

            // Only force bottom-right placement on the very first run; afterwards
            // the window-state plugin restores the user's last position.
            if !has_saved_window_state(app.handle()) {
                if let Some(pet) = app.get_webview_window("pet") {
                    place_bottom_right(&pet);
                }
            }

            // Start keyboard monitoring + the state ticker, and share the state.
            let state = runtime::launch(app.handle());
            app.manage(state);
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
