use std::io::{BufRead, BufReader};
use std::net::TcpStream;
use std::thread;
use std::time::Duration;

use crate::state::State;

#[derive(Clone, Copy)]
pub enum Format {
    /// The raw JSON line from the daemon.
    Json,
    /// Just the layer name, upper-cased; empty while kanata is unreachable.
    Layer,
    /// Layer upper-cased, then the held mods as initials: `NAV +CS`.
    Line,
}

fn render(line: &str, format: Format) -> Option<String> {
    match format {
        Format::Json => Some(line.to_owned()),
        Format::Layer => {
            let state: State = serde_json::from_str(line).ok()?;
            Some(state.layer.to_uppercase())
        }
        Format::Line => {
            let state: State = serde_json::from_str(line).ok()?;
            let initials: String = state
                .mods
                .iter()
                .filter_map(|m| m.chars().next())
                .map(|c| c.to_ascii_uppercase())
                .collect();
            let layer = state.layer.to_uppercase();
            Some(if initials.is_empty() || layer.is_empty() {
                layer
            } else {
                format!("{layer} +{initials}")
            })
        }
    }
}

/// Prints the current state once and exits; fails if the daemon is unreachable.
pub fn get(addr: &str, format: Format) -> std::io::Result<()> {
    let stream = TcpStream::connect(addr)?;
    let mut line = String::new();
    BufReader::new(stream).read_line(&mut line)?;
    if let Some(out) = render(line.trim_end(), format) {
        println!("{out}");
    }
    Ok(())
}

/// Prints every state change, reconnecting forever. A lost daemon prints as a disconnected state.
pub fn watch(addr: &str, format: Format) -> std::io::Result<()> {
    let mut last = None;
    loop {
        if let Ok(stream) = TcpStream::connect(addr) {
            for line in BufReader::new(stream).lines().map_while(Result::ok) {
                emit(render(&line, format), &mut last);
            }
        }
        emit(
            render(State::disconnected().line().trim_end(), format),
            &mut last,
        );
        thread::sleep(Duration::from_secs(2));
    }
}

/// Prints only when the rendered output changed, so formats that hide fields stay quiet.
fn emit(out: Option<String>, last: &mut Option<String>) {
    if let Some(out) = out
        && last.as_ref() != Some(&out)
    {
        println!("{out}");
        *last = Some(out);
    }
}
