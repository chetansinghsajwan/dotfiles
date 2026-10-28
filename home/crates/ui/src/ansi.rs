//! ANSI text (as printed by `ps`, `bat --color=always`, ...) to ratatui lines.
//! Handles SGR color and attribute codes; every other escape sequence is dropped.

use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};

fn basic(n: u8, bright: bool) -> Color {
    match (n, bright) {
        (0, false) => Color::Black,
        (1, false) => Color::Red,
        (2, false) => Color::Green,
        (3, false) => Color::Yellow,
        (4, false) => Color::Blue,
        (5, false) => Color::Magenta,
        (6, false) => Color::Cyan,
        (7, false) => Color::Gray,
        (0, true) => Color::DarkGray,
        (1, true) => Color::LightRed,
        (2, true) => Color::LightGreen,
        (3, true) => Color::LightYellow,
        (4, true) => Color::LightBlue,
        (5, true) => Color::LightMagenta,
        (6, true) => Color::LightCyan,
        _ => Color::White,
    }
}

fn apply(style: Style, params: &[u32]) -> Style {
    let mut s = style;
    let mut i = 0;
    while i < params.len() {
        let p = params[i];
        match p {
            0 => s = Style::default(),
            1 => s = s.add_modifier(Modifier::BOLD),
            2 => s = s.add_modifier(Modifier::DIM),
            3 => s = s.add_modifier(Modifier::ITALIC),
            4 => s = s.add_modifier(Modifier::UNDERLINED),
            7 => s = s.add_modifier(Modifier::REVERSED),
            9 => s = s.add_modifier(Modifier::CROSSED_OUT),
            22 => s = s.remove_modifier(Modifier::BOLD | Modifier::DIM),
            23 => s = s.remove_modifier(Modifier::ITALIC),
            24 => s = s.remove_modifier(Modifier::UNDERLINED),
            27 => s = s.remove_modifier(Modifier::REVERSED),
            29 => s = s.remove_modifier(Modifier::CROSSED_OUT),
            30..=37 => s = s.fg(basic((p - 30) as u8, false)),
            39 => s.fg = None,
            40..=47 => s = s.bg(basic((p - 40) as u8, false)),
            49 => s.bg = None,
            90..=97 => s = s.fg(basic((p - 90) as u8, true)),
            100..=107 => s = s.bg(basic((p - 100) as u8, true)),
            38 | 48 => {
                let color = match params.get(i + 1) {
                    Some(5) => params.get(i + 2).map(|&n| (Color::Indexed(n as u8), 2)),
                    Some(2) => match (params.get(i + 2), params.get(i + 3), params.get(i + 4)) {
                        (Some(&r), Some(&g), Some(&b)) => Some((Color::Rgb(r as u8, g as u8, b as u8), 4)),
                        _ => None,
                    },
                    _ => None,
                };
                if let Some((c, used)) = color {
                    s = if p == 38 { s.fg(c) } else { s.bg(c) };
                    i += used;
                }
            }
            _ => {}
        }
        i += 1;
    }
    s
}

/// Parse `text` into lines (split on `\n`; `\r` is dropped, tabs become 4 spaces).
pub fn parse(text: &str) -> Vec<Line<'static>> {
    let mut lines = Vec::new();
    let mut spans: Vec<Span<'static>> = Vec::new();
    let mut cur = String::new();
    let mut style = Style::default();
    let mut chars = text.chars().peekable();

    let flush = |cur: &mut String, spans: &mut Vec<Span<'static>>, style: Style| {
        if !cur.is_empty() {
            spans.push(Span::styled(std::mem::take(cur), style));
        }
    };

    while let Some(c) = chars.next() {
        match c {
            '\x1b' => match chars.peek() {
                Some('[') => {
                    chars.next();
                    let mut body = String::new();
                    let mut end = None;
                    for n in chars.by_ref() {
                        if n.is_ascii_alphabetic() {
                            end = Some(n);
                            break;
                        }
                        body.push(n);
                    }
                    if end == Some('m') {
                        flush(&mut cur, &mut spans, style);
                        let params: Vec<u32> = if body.is_empty() { vec![0] } else { body.split(';').map(|p| p.parse().unwrap_or(0)).collect() };
                        style = apply(style, &params);
                    }
                }
                Some(']') => {
                    // OSC: skip to BEL or ESC \
                    chars.next();
                    while let Some(n) = chars.next() {
                        if n == '\x07' || (n == '\x1b' && chars.peek() == Some(&'\\')) {
                            if n == '\x1b' {
                                chars.next();
                            }
                            break;
                        }
                    }
                }
                _ => {}
            },
            '\n' => {
                flush(&mut cur, &mut spans, style);
                lines.push(Line::from(std::mem::take(&mut spans)));
            }
            '\r' => {}
            '\t' => cur.push_str("    "),
            c if c.is_control() => {}
            c => cur.push(c),
        }
    }
    flush(&mut cur, &mut spans, style);
    if !spans.is_empty() {
        lines.push(Line::from(spans));
    }
    lines
}

#[cfg(test)]
mod tests {
    use super::*;

    fn flat(l: &Line) -> String {
        l.spans.iter().map(|s| s.content.as_ref()).collect()
    }

    #[test]
    fn plain_text_splits_into_lines() {
        let l = parse("one\ntwo\r\n\tthree");
        assert_eq!(l.iter().map(flat).collect::<Vec<_>>(), vec!["one", "two", "    three"]);
    }

    #[test]
    fn colors_and_resets() {
        let l = parse("a\x1b[31mred\x1b[0m b\x1b[1;38;2;1;2;3mX\x1b[0m\n");
        assert_eq!(flat(&l[0]), "ared bX");
        assert_eq!(l[0].spans[1].style.fg, Some(Color::Red));
        assert_eq!(l[0].spans[2].style.fg, None);
        assert_eq!(l[0].spans[3].style.fg, Some(Color::Rgb(1, 2, 3)));
        assert!(l[0].spans[3].style.add_modifier.contains(Modifier::BOLD));
    }

    #[test]
    fn indexed_background_and_unknown_sequences_are_dropped() {
        let l = parse("\x1b[48;5;200mhi\x1b[2K\x1b]0;title\x07!\x1b[m");
        assert_eq!(flat(&l[0]), "hi!");
        assert_eq!(l[0].spans[0].style.bg, Some(Color::Indexed(200)));
    }
}
