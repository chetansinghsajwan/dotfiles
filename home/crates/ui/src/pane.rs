//! `Pane`: the one place a bordered, titled, padded region is drawn.

use crate::theme::Theme;
use ratatui::buffer::Buffer;
use ratatui::layout::Rect;
use ratatui::style::Style;
use ratatui::widgets::{Block, Borders, Padding, Widget};

pub struct Pane<'a> {
    theme: &'a Theme,
    title: Option<&'a str>,
    focused: bool,
}

impl<'a> Pane<'a> {
    pub fn new(theme: &'a Theme) -> Self {
        Pane { theme, title: None, focused: false }
    }

    pub fn title(mut self, title: &'a str) -> Self {
        self.title = Some(title);
        self
    }

    pub fn focused(mut self, focused: bool) -> Self {
        self.focused = focused;
        self
    }

    fn block(&self) -> Block<'a> {
        let c = &self.theme.colors;
        let l = &self.theme.layout;
        let border = if self.focused { c.border_focused } else { c.border };
        let mut block = Block::new()
            .borders(Borders::ALL)
            .border_type(self.theme.chrome.border_type())
            .border_style(Style::new().fg(border.into()))
            .style(if self.theme.chrome.transparent { Style::new().fg(c.fg.into()) } else { Style::new().fg(c.fg.into()).bg(c.bg.into()) })
            .padding(Padding::symmetric(l.padding_x, l.padding_y));
        if let (true, Some(t)) = (self.theme.chrome.titles, self.title) {
            block = block.title(t);
        }
        block
    }

    /// The content rect inside the border and padding.
    pub fn inner(&self, area: Rect) -> Rect {
        self.block().inner(area)
    }
}

impl Widget for Pane<'_> {
    fn render(self, area: Rect, buf: &mut Buffer) {
        self.block().render(area, buf);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ratatui::style::Color;

    fn bg_at(theme: &Theme, x: u16, y: u16) -> Color {
        let area = Rect::new(0, 0, 10, 5);
        let mut buf = Buffer::empty(area);
        Pane::new(theme).title("t").render(area, &mut buf);
        buf[(x, y)].bg
    }

    #[test]
    fn transparent_panes_leave_the_terminal_background_alone() {
        let mut t = Theme::default();
        assert!(t.chrome.transparent, "transparent by default");
        assert_eq!(bg_at(&t, 3, 2), Color::Reset);
        t.chrome.transparent = false;
        assert_eq!(bg_at(&t, 3, 2), Color::from(t.colors.bg));
    }
}
