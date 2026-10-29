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

/// Where the docks, the editor and the ribbon go (see `workbench`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Workbench {
    pub left: Rect,
    pub right: Rect,
    pub bottom: Rect,
    /// What is left for the editor (its box, tabs and text).
    pub editor: Rect,
    /// The very bottom row, full width: the status lines. Empty (height 0) only
    /// when there is no room for it.
    pub ribbon: Rect,
}

/// Split `main` into a left dock, a right dock, a bottom dock, the editor and the
/// ribbon, like the side bars, panel and status bar of VS Code or Zed. The sizes
/// are widths and a height in cells; 0 means the dock is closed. Docks never take
/// more than a third of the width each or half of the height, and the editor
/// keeps a minimum size.
///
/// The ribbon is always the last row of `main`, across the whole width, below
/// every dock. The side docks run from the top down to just above it, and the
/// bottom dock sits under the editor between the side docks.
pub fn workbench(main: Rect, left: u16, right: u16, bottom: u16) -> Workbench {
    const MIN_EDITOR_WIDTH: u16 = 20;
    const MIN_EDITOR_HEIGHT: u16 = 4;
    let ribbon_h = u16::from(main.height > MIN_EDITOR_HEIGHT);
    let body = Rect { height: main.height - ribbon_h, ..main };
    let third = body.width / 3;
    let mut left = left.min(third);
    let mut right = right.min(third);
    while body.width.saturating_sub(left + right) < MIN_EDITOR_WIDTH.min(body.width) && (left > 0 || right > 0) {
        if left >= right { left -= 1 } else { right -= 1 }
    }
    let bottom = bottom.min(body.height / 2).min(body.height.saturating_sub(MIN_EDITOR_HEIGHT));
    let mid_x = body.x + left;
    let mid_w = body.width - left - right;
    Workbench {
        left: Rect { x: body.x, y: body.y, width: left, height: if left == 0 { 0 } else { body.height } },
        right: Rect { x: body.right() - right, y: body.y, width: right, height: if right == 0 { 0 } else { body.height } },
        bottom: Rect { x: mid_x, y: body.bottom() - bottom, width: if bottom == 0 { 0 } else { mid_w }, height: bottom },
        editor: Rect { x: mid_x, y: body.y, width: mid_w, height: body.height - bottom },
        ribbon: Rect { x: main.x, y: body.bottom(), width: main.width, height: ribbon_h },
    }
}

#[cfg(test)]
mod workbench_tests {
    use super::*;

    #[test]
    fn the_ribbon_is_the_whole_bottom_row_and_the_docks_stop_above_it() {
        let main = Rect::new(0, 0, 120, 40);
        let w = workbench(main, 30, 25, 0);
        assert_eq!(w.ribbon, Rect::new(0, 39, 120, 1));
        assert_eq!(w.left, Rect::new(0, 0, 30, 39));
        assert_eq!(w.right, Rect::new(95, 0, 25, 39));
        assert_eq!(w.editor, Rect::new(30, 0, 65, 39));
        assert_eq!(w.bottom.height, 0);
    }

    #[test]
    fn a_bottom_dock_sits_under_the_editor_and_the_ribbon_stays_below_it() {
        let w = workbench(Rect::new(0, 0, 120, 40), 30, 25, 12);
        assert_eq!(w.bottom, Rect::new(30, 27, 65, 12));
        assert_eq!(w.editor, Rect::new(30, 0, 65, 27));
        assert_eq!((w.left.height, w.right.height), (39, 39));
        assert_eq!(w.ribbon, Rect::new(0, 39, 120, 1), "never moves");
        assert_eq!(w.bottom.bottom(), w.ribbon.y, "the dock ends right above the ribbon");
    }

    #[test]
    fn closed_docks_take_no_room_and_big_ones_are_limited() {
        let main = Rect::new(2, 1, 90, 30);
        let w = workbench(main, 0, 0, 0);
        assert_eq!(w.editor, Rect::new(2, 1, 90, 29));
        assert_eq!(w.ribbon, Rect::new(2, 30, 90, 1));
        assert_eq!((w.left.width, w.right.width, w.left.height, w.right.height), (0, 0, 0, 0));
        // At most a third of the width per side and half of the height.
        let w = workbench(main, 80, 80, 100);
        assert_eq!((w.left.width, w.right.width), (30, 30));
        assert_eq!(w.bottom.height, 14);
        assert!(w.editor.width >= 20);
        // The pieces never overlap or leave the area.
        for r in [w.left, w.right, w.bottom, w.editor, w.ribbon] {
            assert!(r.x >= main.x && r.right() <= main.right() && r.y >= main.y && r.bottom() <= main.bottom(), "{r:?}");
        }
        assert!(w.left.right() <= w.editor.x && w.editor.right() <= w.right.x && w.editor.bottom() <= w.bottom.y && w.bottom.bottom() <= w.ribbon.y);
    }

    #[test]
    fn tiny_screens_keep_a_usable_editor_and_drop_the_ribbon_last() {
        let w = workbench(Rect::new(0, 0, 40, 10), 30, 30, 8);
        assert!(w.editor.width >= 20 && w.editor.height >= 4, "{w:?}");
        assert_eq!(w.ribbon.height, 1);
        // With almost no rows left there is no ribbon, and nothing overlaps.
        let w = workbench(Rect::new(0, 0, 40, 4), 10, 10, 10);
        assert_eq!(w.ribbon.height, 0);
        assert_eq!(w.editor.height, 4);
    }
}
