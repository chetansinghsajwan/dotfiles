//! The one-line text prompt (`label value` with a block cursor), shared by
//! pick's query line and the explorer's new/rename/open-with prompts.

use crate::theme::Theme;
use ratatui::buffer::Buffer;
use ratatui::layout::Rect;
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use unicode_width::UnicodeWidthStr;

/// `label` in the accent color followed by the typed `value`.
pub fn line(theme: &Theme, label: &str, value: &str) -> Line<'static> {
    let c = &theme.colors;
    Line::from(vec![Span::styled(label.to_string(), Style::new().fg(c.accent.into())), Span::styled(value.to_string(), Style::new().fg(c.fg.into()))])
}

/// Mark the cursor cell: `cursor` columns into the value, after `label`, on the
/// row `area` (nothing if it falls outside).
pub fn cursor(buf: &mut Buffer, area: Rect, label: &str, cursor: usize) {
    let x = area.x + label.width() as u16 + cursor as u16;
    if x < area.right() {
        if let Some(cell) = buf.cell_mut((x, area.y)) {
            cell.set_style(Style::new().add_modifier(Modifier::REVERSED));
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_cursor_cell_is_reversed_after_the_label() {
        let area = Rect::new(0, 0, 10, 1);
        let mut buf = Buffer::empty(area);
        cursor(&mut buf, area, "> ", 3);
        assert!(buf[(5, 0)].modifier.contains(Modifier::REVERSED));
        assert!(!buf[(4, 0)].modifier.contains(Modifier::REVERSED));
        cursor(&mut buf, area, "> ", 20); // outside: no panic, no mark
    }

    #[test]
    fn line_has_the_label_then_the_value() {
        let l = line(&Theme::default(), "new: ", "a.rs");
        assert_eq!(l.spans.iter().map(|s| s.content.as_ref()).collect::<String>(), "new: a.rs");
    }
}
