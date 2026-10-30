//! List rows: the one place that decides how a row of a list is laid out and
//! highlighted, so every tool's lists (files, pick, git, diagnostics) look alike.
//!
//! A row's *bar* (its background) spans the pane's padding on both sides, so the
//! highlight touches the borders; its *content* stays inside the padding, giving
//! the text a one-cell margin within the bar.

use crate::theme::{Theme, mix};
use ratatui::layout::Rect;
use ratatui::style::{Color, Modifier, Style};

#[derive(Debug, Clone, Copy)]
pub struct Rows {
    inner: Rect,
    left: u16,
    right: u16,
}

impl Rows {
    /// `pane` is the whole pane, `inner` the list's area inside its border and padding.
    pub fn new(pane: Rect, inner: Rect) -> Rows {
        let left = inner.x.saturating_sub(pane.x + 1).min(1);
        let right = pane.right().saturating_sub(inner.right() + 1).min(1);
        Rows { inner, left, right }
    }

    /// The row's background at `y`, reaching into the padding on both sides.
    pub fn bar(&self, y: u16) -> Rect {
        Rect { x: self.inner.x - self.left, y, width: self.inner.width + self.left + self.right, height: 1 }
    }

    /// The row's content area at `y`, inside the padding.
    pub fn content(&self, y: u16) -> Rect {
        Rect { y, height: 1, ..self.inner }
    }
}

/// The style of a row's bar: a faded blue (the accent) for the hovered row, a faded
/// tint of `tint` (a git color, say) for a row that has one, nothing otherwise.
pub fn style(theme: &Theme, hovered: bool, tint: Option<Color>) -> Style {
    let c = &theme.colors;
    match (hovered, tint) {
        (true, _) => Style::new().bg(mix(c.accent.into(), c.bg.into(), 28)).add_modifier(Modifier::BOLD),
        (false, Some(t)) => Style::new().bg(mix(t, c.bg.into(), 14)),
        (false, None) => Style::new(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_bar_reaches_the_borders_and_the_content_stays_inside() {
        let pane = Rect::new(0, 0, 20, 6);
        let inner = Rect::new(2, 1, 16, 4); // border 1 + padding 1 on each side
        let rows = Rows::new(pane, inner);
        assert_eq!(rows.bar(2), Rect::new(1, 2, 18, 1));
        assert_eq!(rows.content(2), Rect::new(2, 2, 16, 1));
        // No padding: the bar is the content.
        let rows = Rows::new(pane, Rect::new(1, 1, 18, 4));
        assert_eq!(rows.bar(1), rows.content(1));
    }

    #[test]
    fn hovered_beats_tint_and_plain_rows_have_no_background() {
        let t = Theme::default();
        assert!(style(&t, true, Some(Color::Red)).bg.is_some());
        assert_ne!(style(&t, true, None).bg, style(&t, false, Some(Color::Red)).bg);
        assert_eq!(style(&t, false, None).bg, None);
    }
}
