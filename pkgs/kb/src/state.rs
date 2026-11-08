use serde::{Deserialize, Serialize};

/// What every client sees: one JSON object per line, sent on connect and on every change.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct State {
    /// Active kanata layer; empty while kanata is unreachable.
    pub layer: String,
    /// Held modifiers, a subset of `ctrl`, `shift`, `alt`, `meta` (not reported yet).
    pub mods: Vec<String>,
    /// Whether the daemon currently has a connection to kanata.
    pub kanata: bool,
}

impl State {
    pub fn disconnected() -> Self {
        State {
            layer: String::new(),
            mods: Vec::new(),
            kanata: false,
        }
    }

    pub fn line(&self) -> String {
        let mut line = serde_json::to_string(self).expect("State serializes");
        line.push('\n');
        line
    }
}
