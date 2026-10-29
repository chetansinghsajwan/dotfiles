//! `Pane`: the one place a bordered, titled, padded region is drawn.

use crate::theme::Theme;
use ratatui::buffer::Buffer;
use ratatui::layout::Rect;
use crate::icons::Icon;
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Padding, Widget};

pub struct Pane<'a> {
    theme: &'a Theme,
    title: Option<&'a str>,
    icon: Option<Icon>,
    focused: bool,
}

impl<'a> Pane<'a> {
    pub fn new(theme: &'a Theme) -> Self {
        Pane { theme, title: None, icon: None, focused: false }
    }

    pub fn title(mut self, title: &'a str) -> Self {
        self.title = Some(title);
        self
    }

    /// An icon shown before the title (see `ui::icons`).
    pub fn icon(mut self, icon: Icon) -> Self {
        self.icon = Some(icon);
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
            block = block.title(self.title_line(t, border.into()));
        }
        block
    }

    /// `─ icon title ─`: set off from the corner by a bar and a space on each side;
    /// bold accent when the pane is focused, muted otherwise.
    fn title_line(&self, title: &str, border: ratatui::style::Color) -> Line<'a> {
        let c = &self.theme.colors;
        let bar = self.theme.chrome.border_type().to_border_set().horizontal_top;
        let style = if self.focused { Style::new().fg(c.accent.into()).add_modifier(Modifier::BOLD) } else { Style::new().fg(c.muted.into()) };
        let mut spans = vec![Span::styled(bar, Style::new().fg(border)), Span::raw(" ")];
        if let Some(i) = self.icon {
            spans.push(Span::styled(format!("{} ", i.glyph), Style::new().fg(i.color)));
        }
        spans.push(Span::styled(title.to_string(), style));
        spans.push(Span::raw(" "));
        Line::from(spans)
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
