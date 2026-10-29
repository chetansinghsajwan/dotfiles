//! The git panel: the shared `git-panel` (dotfiles/home/crates/git-panel) as a
//! popup, like the pickers. Same bridge as `pick.rs`: helix keys are converted
//! for the panel, which draws into a ratatui buffer that is copied onto the
//! helix surface; colors, sizes and borders come from the shared `ui` tokens.

use super::pick::{copy, to_crossterm};
use crate::compositor::{Component, Context, Event, EventResult};
use helix_view::graphics::{CursorKind, Rect};
use ratatui::buffer::Buffer as RBuffer;
use ratatui::layout::Rect as RRect;
use std::path::Path;
use tui::buffer::Buffer as Surface;

pub struct GitPanelComponent {
    panel: git_panel::Panel,
    theme: tui_design::Theme,
}

impl GitPanelComponent {
    /// The panel for the repository containing `path`; `None` if there is none.
    pub fn new(path: &Path) -> Option<Self> {
        Some(GitPanelComponent { panel: git_panel::Panel::new(path)?, theme: tui_design::Theme::load() })
    }
}

impl Component for GitPanelComponent {
    fn handle_event(&mut self, event: &Event, _cx: &mut Context) -> EventResult {
        let Event::Key(key) = event else {
            return EventResult::Ignored(None);
        };
        let Some(ev) = to_crossterm(key) else {
            return EventResult::Consumed(None);
        };
        match self.panel.handle_event(&ratatui::crossterm::event::Event::Key(ev)) {
            git_panel::Action::None | git_panel::Action::Changed => EventResult::Consumed(None),
            git_panel::Action::Close => EventResult::Consumed(Some(Box::new(|compositor, _| {
                compositor.pop();
            }))),
            git_panel::Action::Open(path) => EventResult::Consumed(Some(Box::new(move |compositor, cx| {
                compositor.pop();
                if let Err(e) = cx.editor.open(&path, helix_view::editor::Action::Replace) {
                    cx.editor.set_error(format!("Failed to open {}: {e}", path.display()));
                }
            }))),
        }
    }

    fn render(&mut self, area: Rect, surface: &mut Surface, _cx: &mut Context) {
        // A popup over the editor, sized by the shared `popup_percent` token.
        let full = RRect::new(area.x, area.y, area.width, area.height);
        let p = tui_design::layout::popup(&self.theme, full);
        let popup = Rect::new(p.x, p.y, p.width, p.height);
        let r = RRect::new(0, 0, popup.width, popup.height);
        let mut buf = RBuffer::empty(r);
        self.panel.render(r, &mut buf, &self.theme);
        copy(&buf, popup, surface);
    }

    fn cursor(&self, _area: Rect, _editor: &helix_view::Editor) -> (Option<helix_core::Position>, CursorKind) {
        (None, CursorKind::Hidden)
    }
}
