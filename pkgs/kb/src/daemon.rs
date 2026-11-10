use std::io::{BufRead, BufReader, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::mpsc::{self, Sender};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

use crate::state::State;

const RECONNECT_DELAY: Duration = Duration::from_secs(2);

/// Current state plus one channel per connected client.
struct Hub {
    state: State,
    subs: Vec<Sender<String>>,
}

impl Hub {
    fn update(&mut self, f: impl FnOnce(&mut State)) {
        let before = self.state.clone();
        f(&mut self.state);
        if self.state != before {
            let line = self.state.line();
            self.subs.retain(|tx| tx.send(line.clone()).is_ok());
        }
    }
}

type Shared = Arc<Mutex<Hub>>;

pub fn run(kanata_addr: String, listen_addr: String, mods_device: String) -> std::io::Result<()> {
    let hub: Shared = Arc::new(Mutex::new(Hub {
        state: State::disconnected(),
        subs: Vec::new(),
    }));

    let listener = TcpListener::bind(&listen_addr)?;
    eprintln!("kb: serving on {listen_addr}, following kanata at {kanata_addr}");

    let kanata_hub = Arc::clone(&hub);
    thread::spawn(move || follow_kanata(&kanata_addr, &kanata_hub));

    follow_mods(mods_device, &hub);

    for stream in listener.incoming().flatten() {
        let hub = Arc::clone(&hub);
        thread::spawn(move || serve_client(stream, &hub));
    }
    Ok(())
}

/// Stores the held keys and the modifiers among them.
fn set_keys(state: &mut State, keys: Vec<String>) {
    state.mods = crate::keys::mods_of(&keys);
    state.keys = keys;
}

/// Mirrors held keys into the hub.
#[cfg(all(target_os = "linux", target_pointer_width = "64"))]
fn follow_mods(device: String, hub: &Shared) {
    let hub = Arc::clone(hub);
    thread::spawn(move || {
        crate::mods::linux::watch(&device, |held| hub.lock().unwrap().update(|s| set_keys(s, held)));
    });
}

#[cfg(windows)]
fn follow_mods(_device: String, hub: &Shared) {
    let hub = Arc::clone(hub);
    thread::spawn(move || {
        crate::mods::windows::watch(|held| hub.lock().unwrap().update(|s| set_keys(s, held)));
    });
}

#[cfg(target_os = "macos")]
fn follow_mods(_device: String, hub: &Shared) {
    let hub = Arc::clone(hub);
    thread::spawn(move || {
        crate::mods::macos::watch(|held| hub.lock().unwrap().update(|s| set_keys(s, held)));
    });
}

#[cfg(not(any(
    all(target_os = "linux", target_pointer_width = "64"),
    windows,
    target_os = "macos"
)))]
fn follow_mods(_device: String, _hub: &Shared) {}

fn serve_client(mut stream: TcpStream, hub: &Shared) {
    let (tx, rx) = mpsc::channel();
    let first = {
        let mut hub = hub.lock().unwrap();
        hub.subs.push(tx);
        hub.state.line()
    };
    if stream.write_all(first.as_bytes()).is_err() {
        return;
    }
    for line in rx {
        if stream.write_all(line.as_bytes()).is_err() {
            return;
        }
    }
}

/// Mirrors kanata's layer into the hub, reconnecting forever.
fn follow_kanata(addr: &str, hub: &Shared) {
    loop {
        if let Ok(stream) = TcpStream::connect(addr) {
            read_kanata(stream, hub);
        }
        hub.lock().unwrap().update(|s| {
            s.layer.clear();
            s.kanata = false;
        });
        thread::sleep(RECONNECT_DELAY);
    }
}

fn read_kanata(mut stream: TcpStream, hub: &Shared) {
    hub.lock().unwrap().update(|s| s.kanata = true);

    // Kanata pushes LayerChange to every client on its own (there is no subscribe message, and an
    // unknown one gets us disconnected); the reply to this request seeds the layer all the same.
    let hello = "{\"RequestCurrentLayerName\":{}}\n";
    if stream.write_all(hello.as_bytes()).is_err() {
        return;
    }
    for line in BufReader::new(stream).lines().map_while(Result::ok) {
        if let Some(layer) = layer_of(&line) {
            hub.lock().unwrap().update(|s| s.layer = layer);
        }
    }
}

/// The layer named by a kanata message, if it is one that carries a layer.
fn layer_of(line: &str) -> Option<String> {
    let msg: serde_json::Value = serde_json::from_str(line).ok()?;
    let name = msg
        .pointer("/LayerChange/new")
        .or_else(|| msg.pointer("/CurrentLayerName/name"))?;
    name.as_str().map(str::to_owned)
}

#[cfg(test)]
mod tests {
    use super::layer_of;

    #[test]
    fn layer_change_and_current_layer_name() {
        assert_eq!(
            layer_of(r#"{"LayerChange":{"new":"nav"}}"#),
            Some("nav".into())
        );
        assert_eq!(
            layer_of(r#"{"CurrentLayerName":{"name":"main"}}"#),
            Some("main".into())
        );
    }

    #[test]
    fn other_messages_are_ignored() {
        assert_eq!(layer_of(r#"{"status":"Ok"}"#), None);
        assert_eq!(layer_of(r#"{"LayerNames":{"names":["main"]}}"#), None);
        assert_eq!(layer_of("not json"), None);
    }
}
