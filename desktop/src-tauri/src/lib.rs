#[cfg(debug_assertions)]
mod debug;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // window size and position are remembered between launches
    let builder = tauri::Builder::default().plugin(tauri_plugin_window_state::Builder::default().build());
    #[cfg(debug_assertions)]
    let builder = debug::attach(builder);
    builder
        .run(tauri::generate_context!())
        .expect("error while running Raffronto");
}
