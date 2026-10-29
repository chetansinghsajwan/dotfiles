//! Docks: a left sidebar, a right sidebar and a bottom panel around the editor,
//! like VS Code and Zed. Each dock holds one or more panels (`files`, `git`) that
//! the user assigns in `editor.docks`; one panel shows at a time and `[` / `]`
//! switch. The shared panels are drawn by ratatui and copied onto the helix
//! surface (see `pick.rs`); sizes and colors come from the shared `ui` tokens.
//! The layout itself is `tui_design::layout::workbench`.

use super::pick::{copy, to_crossterm};
use helix_view::editor::DocksConfig;
use helix_view::graphics::Rect;
use helix_view::input::KeyEvent;
use ratatui::buffer::Buffer as RBuffer;
use ratatui::layout::Rect as RRect;
use ratatui::style::{Modifier, Style as RStyle};
use ratatui::crossterm::event as ct;
use std::path::{Path, PathBuf};
use tui::buffer::Buffer as Surface;

pub fn to_ratatui(r: Rect) -> RRect {
    RRect::new(r.x, r.y, r.width, r.height)
}

pub fn from_ratatui(r: RRect) -> Rect {
    Rect::new(r.x, r.y, r.width, r.height)
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Side {
    Left,
    Right,
    Bottom,
}

/// What a panel asks the editor to do after a key.
#[derive(Debug, PartialEq, Eq)]
pub enum PanelEvent {
    None,
    /// Open this file.
    Open(PathBuf),
    /// Give the keyboard back to the editor.
    Unfocus,
    /// A file or folder was created.
    Created(PathBuf, bool),
    /// Files were renamed or moved; open buffers should follow.
    Moved(Vec<(PathBuf, PathBuf)>),
}

/// A panel that can sit in a dock.
pub trait DockPanel {
    fn id(&self) -> &'static str;
    fn render(&mut self, buf: &mut RBuffer, area: RRect, theme: &tui_design::Theme, focused: bool);
    fn handle_key(&mut self, key: ct::KeyEvent) -> PanelEvent;
    /// Show this file (the file explorer expands to it).
    fn reveal(&mut self, _path: &Path) {}
}

struct FilesDock(files::Panel);

impl DockPanel for FilesDock {
    fn id(&self) -> &'static str {
        "files"
    }

    fn render(&mut self, buf: &mut RBuffer, area: RRect, theme: &tui_design::Theme, focused: bool) {
        self.0.render(area, buf, theme, focused);
    }

    fn handle_key(&mut self, key: ct::KeyEvent) -> PanelEvent {
        match self.0.handle_event(&ct::Event::Key(key)) {
            files::Action::Open(p) => PanelEvent::Open(p),
            files::Action::Close => PanelEvent::Unfocus,
            files::Action::Created(p, d) => PanelEvent::Created(p, d),
            files::Action::Moved(m) => PanelEvent::Moved(m),
            files::Action::Deleted(_) | files::Action::None => PanelEvent::None,
        }
    }

    fn reveal(&mut self, path: &Path) {
        self.0.reveal(path);
    }
}

/// The changed files (no diff pane: use `space g` for the full panel).
struct GitDock(git_panel::Panel);

impl DockPanel for GitDock {
    fn id(&self) -> &'static str {
        "git"
    }

    fn render(&mut self, buf: &mut RBuffer, area: RRect, theme: &tui_design::Theme, focused: bool) {
        self.0.render_compact(area, buf, theme, focused);
    }

    fn handle_key(&mut self, key: ct::KeyEvent) -> PanelEvent {
        match self.0.handle_event(&ct::Event::Key(key)) {
            git_panel::Action::Open(p) => PanelEvent::Open(p),
            git_panel::Action::Close => PanelEvent::Unfocus,
            git_panel::Action::Changed | git_panel::Action::None => PanelEvent::None,
        }
    }
}

fn make_panel(id: &str, root: &Path) -> Option<Box<dyn DockPanel>> {
    match id {
        "files" => Some(Box::new(FilesDock(files::Panel::new(root, files::PanelOptions::default())))),
        "git" => git_panel::Panel::new(root).map(|p| Box::new(GitDock(p)) as Box<dyn DockPanel>),
        _ => None,
    }
}

/// One dock: the panels assigned to it (built when first shown) and its state.
#[derive(Default)]
pub struct Dock {
    ids: Vec<String>,
    panels: Vec<Option<Box<dyn DockPanel>>>,
    active: usize,
    pub open: bool,
    pub focused: bool,
}

impl Dock {
    fn assign(&mut self, ids: &[String]) {
        if self.ids == ids {
            return;
        }
        self.ids = ids.to_vec();
        self.panels = ids.iter().map(|_| None).collect();
        self.active = self.active.min(ids.len().saturating_sub(1));
        if ids.is_empty() {
            self.open = false;
            self.focused = false;
        }
    }

    /// Open docks that hold a panel take room; empty ones never do.
    fn shown(&self) -> bool {
        self.open && !self.ids.is_empty()
    }

    fn active_panel(&mut self, root: &Path) -> Option<&mut Box<dyn DockPanel>> {
        let i = self.active;
        if self.panels.get(i)?.is_none() {
            self.panels[i] = make_panel(&self.ids[i], root);
        }
        self.panels[i].as_mut()
    }

    fn cycle(&mut self, delta: isize) {
        let n = self.ids.len() as isize;
        if n > 1 {
            self.active = (self.active as isize + delta).rem_euclid(n) as usize;
        }
    }

    /// Tab labels over the top border when the dock holds several panels.
    fn draw_tabs(&self, buf: &mut RBuffer, area: RRect, theme: &tui_design::Theme) {
        if self.ids.len() < 2 || area.width < 6 {
            return;
        }
        let c = &theme.colors;
        let mut x = area.x + 2;
        for (i, id) in self.ids.iter().enumerate() {
            let style = if i == self.active { RStyle::new().fg(c.accent.into()).add_modifier(Modifier::BOLD) } else { RStyle::new().fg(c.muted.into()) };
            let label = format!(" {id} ");
            if x + label.chars().count() as u16 >= area.right() {
                break;
            }
            buf.set_string(x, area.y, &label, style);
            x += label.chars().count() as u16;
        }
    }
}

#[derive(Default)]
pub struct Docks {
    pub left: Dock,
    pub right: Dock,
    pub bottom: Dock,
    root: Option<PathBuf>,
    theme: Option<tui_design::Theme>,
    last: Option<DocksConfig>,
}

impl Docks {
    fn theme(&mut self) -> &tui_design::Theme {
        self.theme.get_or_insert_with(tui_design::Theme::load)
    }

    fn dock(&mut self, side: Side) -> &mut Dock {
        match side {
            Side::Left => &mut self.left,
            Side::Right => &mut self.right,
            Side::Bottom => &mut self.bottom,
        }
    }

    /// Apply the configuration (which panels go where) and the workspace root.
    /// Open/closed state survives a change; panels are rebuilt when their dock's
    /// assignment or the root changed.
    pub fn configure(&mut self, cfg: &DocksConfig, root: PathBuf) {
        if self.root.as_ref() != Some(&root) {
            for d in [&mut self.left, &mut self.right, &mut self.bottom] {
                d.panels = d.ids.iter().map(|_| None).collect();
            }
            self.root = Some(root);
        }
        if self.last.as_ref() != Some(cfg) {
            self.left.assign(&cfg.left);
            self.right.assign(&cfg.right);
            self.bottom.assign(&cfg.bottom);
            self.last = Some(cfg.clone());
        }
    }

    pub fn focused_side(&self) -> Option<Side> {
        [(Side::Left, &self.left), (Side::Right, &self.right), (Side::Bottom, &self.bottom)].into_iter().find(|(_, d)| d.shown() && d.focused).map(|(s, _)| s)
    }

    pub fn unfocus(&mut self) {
        for d in [&mut self.left, &mut self.right, &mut self.bottom] {
            d.focused = false;
        }
    }

    /// Open and focus the dock; if it is already focused, close it. A dock that
    /// holds no panel does nothing and returns `false`.
    pub fn toggle(&mut self, side: Side, current: Option<&Path>) -> bool {
        if self.dock(side).ids.is_empty() {
            return false;
        }
        if self.dock(side).shown() && self.dock(side).focused {
            let d = self.dock(side);
            d.open = false;
            d.focused = false;
            return true;
        }
        self.focus(side, current);
        true
    }

    fn focus(&mut self, side: Side, current: Option<&Path>) {
        self.unfocus();
        let root = self.root.clone().unwrap_or_default();
        let d = self.dock(side);
        d.open = true;
        d.focused = true;
        if let (Some(path), Some(panel)) = (current, d.active_panel(&root)) {
            panel.reveal(path);
        }
    }

    /// Show a panel by name in the dock it is assigned to: switch to it, open the
    /// dock and focus it; if it is already focused, close the dock. `false` if no
    /// dock holds that panel.
    pub fn show_panel(&mut self, id: &str, current: Option<&Path>) -> bool {
        let Some((side, index)) = [Side::Left, Side::Right, Side::Bottom].into_iter().find_map(|s| self.dock(s).ids.iter().position(|p| p == id).map(|i| (s, i))) else {
            return false;
        };
        let d = self.dock(side);
        let already = d.shown() && d.focused && d.active == index;
        d.active = index;
        if already {
            d.open = false;
            d.focused = false;
        } else {
            self.focus(side, current);
        }
        true
    }

    /// Rows and columns the docks take: `(left, right, bottom)` in cells.
    pub fn sizes(&mut self) -> (u16, u16, u16) {
        let (w, h) = {
            let t = self.theme();
            (t.layout.sidebar_width, t.layout.bottom_height)
        };
        (if self.left.shown() { w } else { 0 }, if self.right.shown() { w } else { 0 }, if self.bottom.shown() { h } else { 0 })
    }

    pub fn render(&mut self, wb: &tui_design::layout::Workbench, surface: &mut Surface) {
        let theme = self.theme().clone();
        let root = self.root.clone().unwrap_or_default();
        for (side, rect) in [(Side::Left, wb.left), (Side::Right, wb.right), (Side::Bottom, wb.bottom)] {
            let d = self.dock(side);
            if !d.shown() || rect.width == 0 || rect.height == 0 {
                continue;
            }
            let focused = d.focused;
            let local = RRect::new(0, 0, rect.width, rect.height);
            let mut buf = RBuffer::empty(local);
            match d.active_panel(&root) {
                Some(panel) => panel.render(&mut buf, local, &theme, focused),
                None => buf.set_string(1, 0, "unavailable here", RStyle::new().fg(theme.colors.muted.into())),
            }
            d.draw_tabs(&mut buf, local, &theme);
            copy(&buf, from_ratatui(rect), surface);
        }
    }

    /// Route a key to the focused dock. `None` if no dock has the keyboard.
    pub fn handle_key(&mut self, key: &KeyEvent) -> Option<PanelEvent> {
        let side = self.focused_side()?;
        let ev = to_crossterm(key)?;
        let root = self.root.clone().unwrap_or_default();
        let d = self.dock(side);
        // `[` and `]` switch between the panels of a dock.
        match ev.code {
            ct::KeyCode::Char('[') if ev.modifiers.is_empty() => {
                d.cycle(-1);
                return Some(PanelEvent::None);
            }
            ct::KeyCode::Char(']') if ev.modifiers.is_empty() => {
                d.cycle(1);
                return Some(PanelEvent::None);
            }
            _ => {}
        }
        let event = d.active_panel(&root).map(|p| p.handle_key(ev)).unwrap_or(PanelEvent::Unfocus);
        if event == PanelEvent::Unfocus {
            d.focused = false;
        }
        Some(event)
    }
}
