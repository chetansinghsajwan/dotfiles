//! ratatui lines to ANSI escape output.

use ratatui::style::{Color, Modifier, Style};
use ratatui::text::Line;
use std::fmt::Write;

fn sgr(style: Style) -> String {
    let mut codes: Vec<String> = Vec::new();
    let m = style.add_modifier;
    if m.contains(Modifier::BOLD) {
        codes.push("1".into());
    }
    if m.contains(Modifier::DIM) {
        codes.push("2".into());
    }
    if m.contains(Modifier::ITALIC) {
        codes.push("3".into());
    }
    if m.contains(Modifier::UNDERLINED) {
        codes.push("4".into());
    }
    if let Some(Color::Rgb(r, g, b)) = style.fg {
        codes.push(format!("38;2;{r};{g};{b}"));
    }
    if let Some(Color::Rgb(r, g, b)) = style.bg {
        codes.push(format!("48;2;{r};{g};{b}"));
    }
    if codes.is_empty() {
        String::new()
    } else {
        format!("\x1b[{}m", codes.join(";"))
    }
}

/// Serialize lines with truecolor SGR codes, one `\n` per line.
pub fn to_ansi(lines: &[Line<'_>]) -> String {
    let mut out = String::new();
    for line in lines {
        for span in &line.spans {
            let style = line.style.patch(span.style);
            let code = sgr(style);
            if code.is_empty() {
                out.push_str(&span.content);
            } else {
                let _ = write!(out, "{code}{}\x1b[0m", span.content);
            }
        }
        out.push('\n');
    }
    out
}
