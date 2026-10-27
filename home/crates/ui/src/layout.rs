//! Screen splitting. Tools ask for rects here instead of computing their own,
//! so the pane gap and ratios come from the theme.

use crate::theme::Theme;
use ratatui::layout::{Constraint, Direction, Layout, Rect};

/// Split `area` into columns with the theme's gap between them.
pub fn columns(theme: &Theme, area: Rect, constraints: &[Constraint]) -> Vec<Rect> {
    split(theme, area, Direction::Horizontal, constraints)
}

/// Split `area` into rows with the theme's gap between them.
pub fn rows(theme: &Theme, area: Rect, constraints: &[Constraint]) -> Vec<Rect> {
    split(theme, area, Direction::Vertical, constraints)
}

fn split(theme: &Theme, area: Rect, dir: Direction, constraints: &[Constraint]) -> Vec<Rect> {
    Layout::new(dir, constraints)
        .spacing(theme.layout.gap)
        .split(area)
        .to_vec()
}

/// `[sidebar | main | preview]` using the theme's sidebar width and preview share.
pub fn sidebar_main_preview(theme: &Theme, area: Rect) -> [Rect; 3] {
    let l = &theme.layout;
    let p = l.preview_percent.min(100);
    let rest = area.width.saturating_sub(l.sidebar_width + 2 * l.gap);
    let preview = rest * p / 100;
    let v = columns(
        theme,
        area,
        &[
            Constraint::Length(l.sidebar_width),
            Constraint::Min(0),
            Constraint::Length(preview),
        ],
    );
    [v[0], v[1], v[2]]
}

/// `[main | preview]` using the theme's preview share.
pub fn main_preview(theme: &Theme, area: Rect) -> [Rect; 2] {
    let p = theme.layout.preview_percent.min(100);
    let v = columns(
        theme,
        area,
        &[Constraint::Percentage(100 - p), Constraint::Percentage(p)],
    );
    [v[0], v[1]]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn gap_changes_every_split() {
        let area = Rect::new(0, 0, 100, 10);
        let mut t = Theme::default();
        t.layout.gap = 0;
        let a = sidebar_main_preview(&t, area);
        assert_eq!(a[1].x, a[0].right());
        t.layout.gap = 2;
        let b = sidebar_main_preview(&t, area);
        assert_eq!(b[1].x, b[0].right() + 2);
        let c = main_preview(&t, area);
        assert_eq!(c[1].x, c[0].right() + 2);
    }

    #[test]
    fn parses_json() {
        let t: Theme = serde_json::from_str(
            r##"{"chrome":{"border":"double"},"layout":{"gap":3},"colors":{"bg":"#102030"}}"##,
        )
        .unwrap();
        assert_eq!(t.layout.gap, 3);
        assert_eq!(t.chrome.border, "double");
    }
}
