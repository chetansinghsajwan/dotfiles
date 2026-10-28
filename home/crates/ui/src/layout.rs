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

/// A popup centered in `area`, `popup_percent` of its width and height.
pub fn popup(theme: &Theme, area: Rect) -> Rect {
    let p = u32::from(theme.layout.popup_percent.clamp(10, 100));
    let w = (u32::from(area.width) * p / 100) as u16;
    let h = (u32::from(area.height) * p / 100) as u16;
    Rect { x: area.x + (area.width - w) / 2, y: area.y + (area.height - h) / 2, width: w, height: h }
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

#[cfg(test)]
mod popup_tests {
    use super::*;

    #[test]
    fn popup_is_centered_and_follows_the_percent_token() {
        let mut t = Theme::default();
        assert_eq!(t.layout.popup_percent, 80);
        let p = popup(&t, Rect::new(0, 0, 100, 50));
        assert_eq!((p.x, p.y, p.width, p.height), (10, 5, 80, 40));
        t.layout.popup_percent = 100;
        assert_eq!(popup(&t, Rect::new(0, 0, 100, 50)), Rect::new(0, 0, 100, 50));
        t.layout.popup_percent = 50;
        let q = popup(&t, Rect::new(4, 2, 101, 51));
        assert_eq!((q.width, q.height), (50, 25));
        assert!(q.x >= 4 && q.right() <= 105 && q.y >= 2 && q.bottom() <= 53);
        // Out-of-range values are clamped, never larger than the area.
        t.layout.popup_percent = 500;
        assert_eq!(popup(&t, Rect::new(0, 0, 30, 10)), Rect::new(0, 0, 30, 10));
    }
}
