//! The files panel: the shared `files` browser (dotfiles/home/crates/files)
//! as a sidebar. `EditorView` reserves a column for it, renders it, and gives it
//! the keys while it has focus. Like `pick`, it is drawn by ratatui and copied
//! onto the helix surface, with colors and sizes from the shared `ui` tokens.

use super::pick::{copy, to_crossterm};
use helix_view::graphics::Rect;
use helix_view::input::KeyEvent;
use ratatui::buffer::Buffer as RBuffer;
use ratatui::layout::Rect as RRect;
use std::path::{Path, PathBuf};
use tui::buffer::Buffer as Surface;

pub struct FilesSidebar {
    panel: files::Panel,
    theme: tui_design::Theme,
    /// Keys go to the panel while it is focused.
    pub focused: bool,
}

impl FilesSidebar {
    pub fn new(root: PathBuf) -> Self {
        FilesSidebar {
            panel: files::Panel::new(root, files::PanelOptions::default()),
            theme: tui_design::Theme::load(),
            focused: false,
        }
    }

    /// Columns the sidebar takes: the shared `sidebar_width` token.
    pub fn width(&self) -> u16 {
        self.theme.layout.sidebar_width
    }

    /// Expand to `path` and put the cursor on it.
    pub fn reveal(&mut self, path: &Path) {
        self.panel.reveal(path);
    }

    pub fn handle_key(&mut self, key: &KeyEvent) -> files::Action {
        let Some(ev) = to_crossterm(key) else { return files::Action::None };
        self.panel.handle_event(&ratatui::crossterm::event::Event::Key(ev))
    }

    pub fn render(&mut self, area: Rect, surface: &mut Surface) {
        if area.width == 0 || area.height == 0 {
            return;
        }
        let r = RRect::new(0, 0, area.width, area.height);
        let mut buf = RBuffer::empty(r);
        self.panel.render(r, &mut buf, &self.theme, self.focused);
        copy(&buf, area, surface);
    }
}
