use tauri::{
    menu::{Menu, MenuItem},
    tray::TrayIconBuilder,
    Manager, WebviewWindow,
};

/// Move the pet window to the bottom-right corner of the primary monitor,
/// mirroring the macOS app's default placement.
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

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .setup(|app| {
            // macOS: run as a menu-bar agent with no Dock icon.
            #[cfg(target_os = "macos")]
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);

            // Tray icon + menu (show/hide, quit).
            let toggle = MenuItem::with_id(app, "toggle", "显示/隐藏宠物", true, None::<&str>)?;
            let quit = MenuItem::with_id(app, "quit", "退出 KeyboardPet", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&toggle, &quit])?;

            TrayIconBuilder::with_id("main")
                .icon(app.default_window_icon().unwrap().clone())
                .tooltip("KeyboardPet")
                .menu(&menu)
                .show_menu_on_left_click(false)
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "quit" => app.exit(0),
                    "toggle" => {
                        if let Some(w) = app.get_webview_window("pet") {
                            let visible = w.is_visible().unwrap_or(false);
                            let _ = if visible { w.hide() } else { w.show() };
                        }
                    }
                    _ => {}
                })
                .build(app)?;

            if let Some(pet) = app.get_webview_window("pet") {
                place_bottom_right(&pet);
            }
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
