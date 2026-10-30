use crate::compositor::{Component, Context};
use helix_view::graphics::{Margin, Modifier, Rect};
use helix_view::info::Info;
use ratatui::buffer::Buffer as RBuffer;
use ratatui::layout::Rect as RRect;
use ratatui::style::Modifier as RModifier;
use ratatui::widgets::Widget as RWidget;
use tui::buffer::Buffer as Surface;
use tui::text::Text;
use tui::widgets::{Block, Paragraph, Widget};

impl Component for Info {
    fn render(&mut self, viewport: Rect, surface: &mut Surface, cx: &mut Context) {
        let text_style = cx.editor.theme.get("ui.text.info");
        let popup_style = cx.editor.theme.get("ui.popup.info");

        // Calculate the area of the terminal to modify. Because we want to
        // render at the bottom right, we use the viewport's width and height
        // which evaluate to the most bottom right coordinate.
        let width = self.width + 2 + 2; // +2 for border, +2 for margin
        let height = self.height + 2; // +2 for border
        let area = viewport.intersection(Rect::new(
            viewport.width.saturating_sub(width),
            viewport.height.saturating_sub(height + 2), // +2 for statusline
            width,
            height,
        ));
        surface.clear_with(area, popup_style);

        // The frame is the shared pane (rounded border, padded title, focused color),
        // drawn by `ui::Pane` like every other panel and copied onto the surface.
        if area.width >= 2 && area.height >= 2 {
            let theme = tui_design::Theme::load();
            let local = RRect::new(0, 0, area.width, area.height);
            let mut buf = RBuffer::empty(local);
            let title: &str = self.title.as_ref();
            tui_design::Pane::new(&theme).title(title).focused(true).render(local, &mut buf);
            let (w, h) = (area.width, area.height);
            for y in 0..h {
                for x in 0..w {
                    if x == 0 || y == 0 || x == w - 1 || y == h - 1 {
                        let src = &buf[(x, y)];
                        if let Some(dst) = surface.get_mut(area.x + x, area.y + y) {
                            dst.set_symbol(src.symbol());
                            dst.fg = super::pick::color(src.fg);
                            if src.modifier.contains(RModifier::BOLD) {
                                dst.modifier.insert(Modifier::BOLD);
                            }
                        }
                    }
                }
            }
        }

        let margin = Margin::horizontal(1);
        let inner = Block::bordered().inner(area).inner(margin);

        Paragraph::new(&Text::from(self.text.as_str()))
            .style(text_style)
            .render(inner, surface);
    }
}
