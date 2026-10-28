//! Key names for `--expect`: `ctrl-e`, `alt-x`, `f2`, `tab`, `enter`, or a single character.

use ratatui::crossterm::event::{KeyCode, KeyEvent, KeyModifiers};

/// Parse a key name; `None` if it is not understood.
pub fn parse(spec: &str) -> Option<KeyEvent> {
    let mut modifiers = KeyModifiers::NONE;
    let mut rest = spec.trim();
    loop {
        let lower = rest.to_ascii_lowercase();
        if let Some(r) = lower.strip_prefix("ctrl-") {
            modifiers |= KeyModifiers::CONTROL;
            rest = &rest[rest.len() - r.len()..];
        } else if let Some(r) = lower.strip_prefix("alt-") {
            modifiers |= KeyModifiers::ALT;
            rest = &rest[rest.len() - r.len()..];
        } else {
            break;
        }
    }
    let lower = rest.to_ascii_lowercase();
    let code = match lower.as_str() {
        "tab" => KeyCode::Tab,
        "enter" => KeyCode::Enter,
        "space" => KeyCode::Char(' '),
        "esc" => KeyCode::Esc,
        "backspace" => KeyCode::Backspace,
        "delete" => KeyCode::Delete,
        "up" => KeyCode::Up,
        "down" => KeyCode::Down,
        "left" => KeyCode::Left,
        "right" => KeyCode::Right,
        "pgup" | "page-up" => KeyCode::PageUp,
        "pgdn" | "page-down" => KeyCode::PageDown,
        f if f.len() >= 2 && f.starts_with('f') && f[1..].chars().all(|c| c.is_ascii_digit()) => KeyCode::F(f[1..].parse().ok().filter(|n| (1..=12).contains(n))?),
        _ => {
            let mut chars = rest.chars();
            match (chars.next(), chars.next()) {
                (Some(c), None) => KeyCode::Char(c),
                _ => return None,
            }
        }
    };
    Some(KeyEvent::new(code, modifiers))
}

/// Same key, ignoring how the terminal reports event kind and shift on letters.
pub fn matches(event: &KeyEvent, want: &KeyEvent) -> bool {
    let mods = |m: KeyModifiers| m & (KeyModifiers::CONTROL | KeyModifiers::ALT);
    event.code == want.code && mods(event.modifiers) == mods(want.modifiers)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_names_and_matches_events() {
        let k = parse("ctrl-e").unwrap();
        assert_eq!((k.code, k.modifiers), (KeyCode::Char('e'), KeyModifiers::CONTROL));
        assert_eq!(parse("Alt-X").unwrap().modifiers, KeyModifiers::ALT);
        assert_eq!(parse("f2").unwrap().code, KeyCode::F(2));
        assert_eq!(parse("tab").unwrap().code, KeyCode::Tab);
        assert_eq!(parse("ctrl-alt-d").unwrap().modifiers, KeyModifiers::CONTROL | KeyModifiers::ALT);
        assert_eq!(parse("x").unwrap().code, KeyCode::Char('x'));
        for bad in ["", "ctrl-", "f13", "hello", "ctrl-ab"] {
            assert!(parse(bad).is_none(), "{bad}");
        }
        assert!(matches(&KeyEvent::new(KeyCode::Char('e'), KeyModifiers::CONTROL), &parse("ctrl-e").unwrap()));
        assert!(!matches(&KeyEvent::new(KeyCode::Char('e'), KeyModifiers::NONE), &parse("ctrl-e").unwrap()));
    }
}
