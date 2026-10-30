// Development builds only (not compiled in release): the page's console and errors go to the
// terminal, and with RAFFRONTO_DEBUG_PORT set the app runs JavaScript received on that local port,
// one script per connection, starting with the DEBUG_HEADER line (anything else, like a local
// process probing ports, is ignored). Used by scripts/check-app.mjs.
use std::io::Read;
use std::net::TcpListener;
use tauri::{Builder, Manager, Wry};

const DEBUG_HEADER: &str = "//raffronto-debug\n";

const CONSOLE_BRIDGE: &str = r#"
(() => {
  const send = (level, args) => {
    const text = args.map(a => {
      if (a instanceof Error) return a.stack || String(a);
      if (typeof a === 'string') return a;
      try { return JSON.stringify(a); } catch { return String(a); }
    }).join(' ');
    window.__TAURI_INTERNALS__.invoke('debug_log', { level, text }).catch(() => {});
  };
  for (const level of ['log', 'info', 'warn', 'error']) {
    const orig = console[level].bind(console);
    console[level] = (...args) => { orig(...args); send(level, args); };
  }
  addEventListener('error', e => send('error', ['uncaught:', e.message, e.filename + ':' + e.lineno]));
  addEventListener('unhandledrejection', e => send('error', ['unhandled rejection:', e.reason]));
})();
"#;

#[tauri::command]
fn debug_log(level: String, text: String) {
    eprintln!("[page {level}] {text}");
}

pub fn attach(builder: Builder<Wry>) -> Builder<Wry> {
    builder
        .plugin(tauri::plugin::Builder::<Wry, ()>::new("debug-console").js_init_script(CONSOLE_BRIDGE.to_string()).build())
        .invoke_handler(tauri::generate_handler![debug_log])
        .setup(|app| {
            let Ok(port) = std::env::var("RAFFRONTO_DEBUG_PORT") else { return Ok(()) };
            let listener = TcpListener::bind(("127.0.0.1", port.parse::<u16>()?))?;
            let handle = app.handle().clone();
            std::thread::spawn(move || {
                for stream in listener.incoming().flatten() {
                    let mut script = String::new();
                    let mut stream = stream;
                    if stream.read_to_string(&mut script).is_ok() && script.starts_with(DEBUG_HEADER) {
                        if let Some(w) = handle.get_webview_window("main") {
                            let _ = w.eval(&script);
                        }
                    }
                }
            });
            eprintln!("[debug] running scripts sent to 127.0.0.1:{port}");
            Ok(())
        })
}
