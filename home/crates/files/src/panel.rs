use crate::ops;
use git_core::{Kind, Repo, Status};
use ignore::WalkBuilder;
use ratatui::buffer::Buffer;
use ratatui::crossterm::event::{Event, KeyCode, KeyEvent, KeyEventKind, KeyModifiers};
use ratatui::layout::Rect;
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Paragraph, Widget};
use std::collections::BTreeSet;
use std::path::{Path, PathBuf};
use tui_input::backend::crossterm::EventHandler;
use tui_input::Input;
use ui::{Pane, Theme};

#[derive(Debug, Clone)]
pub struct PanelOptions {
    /// Show hidden files (dot files). Toggle with `.`.
    pub hidden: bool,
    /// Git status colors and signs.
    pub git: bool,
}

impl Default for PanelOptions {
    fn default() -> Self {
        PanelOptions { hidden: false, git: true }
    }
}

/// What the host should do after an event.
#[derive(Debug, PartialEq, Eq)]
pub enum Action {
    None,
    /// The user chose a file to open.
    Open(PathBuf),
    /// The user asked to leave the panel (Esc, `q`).
    Close,
    /// A file or (`true`) folder was created.
    Created(PathBuf, bool),
    /// Files were renamed or moved: `(from, to)`. Open buffers should follow.
    Moved(Vec<(PathBuf, PathBuf)>),
    /// Files were trashed or deleted.
    Deleted(Vec<PathBuf>),
    /// The user asked to search: the host runs `pick` and calls `reveal` with the result.
    Search(Search),
    /// Rename these paths together by editing their names in a text editor.
    BulkRename(Vec<PathBuf>),
    /// Open this path with this command (typed in the `open with` prompt).
    OpenWith(PathBuf, String),
}

/// Whether a file has an execute bit (always false off Unix).
fn is_executable(path: &Path) -> bool {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::metadata(path).is_ok_and(|m| m.permissions().mode() & 0o111 != 0)
    }
    #[cfg(not(unix))]
    {
        let _ = path;
        false
    }
}

/// What to search for.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Search {
    /// File names under the root.
    Files,
    /// File contents under the root.
    Grep,
}

struct Row {
    path: PathBuf,
    name: String,
    depth: u16,
    is_dir: bool,
}

enum PromptKind {
    /// Create inside this folder; a trailing `/` makes a folder.
    Create(PathBuf),
    Rename(PathBuf),
    OpenWith(PathBuf),
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum ConfirmKind {
    Trash,
    Delete,
}

enum Mode {
    Normal,
    Prompt(PromptKind, Input),
    Confirm(ConfirmKind, Vec<PathBuf>),
}

/// Yanked (copy) or cut paths waiting for `p`.
struct Clip {
    paths: Vec<PathBuf>,
    cut: bool,
}

pub struct Panel {
    root: PathBuf,
    opts: PanelOptions,
    expanded: BTreeSet<PathBuf>,
    rows: Vec<Row>,
    cursor: usize,
    offset: usize,
    /// Rows visible at the last render, for paging.
    page: usize,
    git: Option<(Repo, Status)>,
    mode: Mode,
    marked: BTreeSet<PathBuf>,
    clip: Option<Clip>,
    /// Last result or error, shown in the footer until the next key.
    message: Option<(String, bool)>,
}

impl Panel {
    pub fn new(root: impl Into<PathBuf>, opts: PanelOptions) -> Self {
        let root = root.into();
        let root = root.canonicalize().unwrap_or(root);
        let mut p = Panel {
            root,
            opts,
            expanded: BTreeSet::new(),
            rows: Vec::new(),
            cursor: 0,
            offset: 0,
            page: 10,
            git: None,
            mode: Mode::Normal,
            marked: BTreeSet::new(),
            clip: None,
            message: None,
        };
        p.refresh();
        p
    }

    pub fn root(&self) -> &Path {
        &self.root
    }

    /// Reread the directories and the git status.
    pub fn refresh(&mut self) {
        self.git = if self.opts.git { Repo::discover(&self.root).and_then(|r| r.status().ok().map(|s| (r, s))) } else { None };
        let keep = self.rows.get(self.cursor).map(|r| r.path.clone());
        self.rows.clear();
        let root = self.root.clone();
        self.build(&root, 0);
        if let Some(path) = keep {
            if let Some(i) = self.rows.iter().position(|r| r.path == path) {
                self.cursor = i;
            }
        }
        self.cursor = self.cursor.min(self.rows.len().saturating_sub(1));
    }

    fn children(&self, dir: &Path) -> Vec<Row> {
        let walk = WalkBuilder::new(dir).max_depth(Some(1)).hidden(!self.opts.hidden).filter_entry(|e| e.file_name() != ".git").build();
        let mut out: Vec<Row> = walk
            .flatten()
            .filter(|e| e.depth() == 1)
            .map(|e| Row {
                name: e.file_name().to_string_lossy().into_owned(),
                is_dir: e.file_type().is_some_and(|t| t.is_dir()),
                path: e.into_path(),
                depth: 0,
            })
            .collect();
        out.sort_by(|a, b| b.is_dir.cmp(&a.is_dir).then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase())));
        out
    }

    fn build(&mut self, dir: &Path, depth: u16) {
        for mut row in self.children(dir) {
            row.depth = depth;
            let open = row.is_dir && self.expanded.contains(&row.path);
            let path = row.path.clone();
            self.rows.push(row);
            if open {
                self.build(&path, depth + 1);
            }
        }
    }

    /// Expand the folders down to `path` and put the cursor on it.
    pub fn reveal(&mut self, path: &Path) {
        let path = path.canonicalize().unwrap_or_else(|_| path.to_path_buf());
        let Ok(rela) = path.strip_prefix(&self.root) else { return };
        let mut dir = self.root.clone();
        for part in rela.parent().into_iter().flat_map(|p| p.components()) {
            dir.push(part);
            self.expanded.insert(dir.clone());
        }
        self.refresh();
        if let Some(i) = self.rows.iter().position(|r| r.path == path) {
            self.cursor = i;
        }
    }

    /// Make `dir` the root of the tree (cd).
    pub fn set_root(&mut self, dir: PathBuf) {
        let dir = dir.canonicalize().unwrap_or(dir);
        self.root = dir;
        self.expanded.clear();
        self.marked.clear();
        self.cursor = 0;
        self.offset = 0;
        self.refresh();
    }

    /// Show a message (or error) in the footer until the next key.
    pub fn notify(&mut self, msg: impl Into<String>, error: bool) {
        self.say(msg, error);
    }

    /// Forget marks and cancel nothing else: call after the host acted on them.
    pub fn clear_marks(&mut self) {
        self.marked.clear();
    }

    /// The marked rows, or the one under the cursor.
    pub fn targets(&self) -> Vec<PathBuf> {
        if self.marked.is_empty() {
            self.current().map(|p| vec![p.to_path_buf()]).unwrap_or_default()
        } else {
            self.marked.iter().cloned().collect()
        }
    }

    /// Path under the cursor.
    pub fn current(&self) -> Option<&Path> {
        self.rows.get(self.cursor).map(|r| r.path.as_path())
    }

    fn move_by(&mut self, delta: isize) {
        let last = self.rows.len().saturating_sub(1) as isize;
        self.cursor = (self.cursor as isize + delta).clamp(0, last.max(0)) as usize;
    }

    fn toggle(&mut self, open: Option<bool>) {
        let Some(row) = self.rows.get(self.cursor) else { return };
        if !row.is_dir {
            return;
        }
        let path = row.path.clone();
        let is_open = self.expanded.contains(&path);
        match (open, is_open) {
            (Some(true), true) | (Some(false), false) => return,
            _ if is_open => self.expanded.remove(&path),
            _ => self.expanded.insert(path),
        };
        self.refresh();
    }

    /// `h`: collapse an open folder, otherwise go to the parent folder's row.
    fn left(&mut self) {
        let Some(row) = self.rows.get(self.cursor) else { return };
        if row.is_dir && self.expanded.contains(&row.path) {
            self.toggle(Some(false));
        } else if let Some(parent) = row.path.parent() {
            if let Some(i) = self.rows.iter().position(|r| r.path == parent) {
                self.cursor = i;
            }
        }
    }

    /// Where `a` and `p` put things: the folder under the cursor, else its parent.
    fn target_dir(&self) -> PathBuf {
        match self.rows.get(self.cursor) {
            Some(r) if r.is_dir => r.path.clone(),
            Some(r) => r.path.parent().map(Path::to_path_buf).unwrap_or_else(|| self.root.clone()),
            None => self.root.clone(),
        }
    }

    fn say(&mut self, msg: impl Into<String>, error: bool) {
        self.message = Some((msg.into(), error));
    }

    /// Whether a prompt or a confirmation is open (keys belong to it, not to the host).
    pub fn is_busy(&self) -> bool {
        !matches!(self.mode, Mode::Normal)
    }

    /// Whether a prompt is taking typed text (so keys like space are text, not commands).
    pub fn is_typing(&self) -> bool {
        matches!(self.mode, Mode::Prompt(..))
    }

    pub fn handle_event(&mut self, ev: &Event) -> Action {
        let Event::Key(key @ KeyEvent { kind, .. }) = ev else { return Action::None };
        if *kind == KeyEventKind::Release {
            return Action::None;
        }
        match std::mem::replace(&mut self.mode, Mode::Normal) {
            Mode::Prompt(kind, input) => return self.prompt_key(kind, input, ev, key),
            Mode::Confirm(kind, targets) => return self.confirm_key(kind, targets, key),
            Mode::Normal => {}
        }
        self.message = None;
        self.normal_key(key)
    }

    fn normal_key(&mut self, key: &KeyEvent) -> Action {
        let ctrl = key.modifiers.contains(KeyModifiers::CONTROL);
        match key.code {
            KeyCode::Esc => {
                if self.marked.is_empty() {
                    return Action::Close;
                }
                self.marked.clear();
            }
            KeyCode::Char('q') => return Action::Close,
            KeyCode::Char('c') if ctrl => return Action::Close,
            KeyCode::Up | KeyCode::Char('k') => self.move_by(-1),
            KeyCode::Down | KeyCode::Char('j') => self.move_by(1),
            KeyCode::Char('p') if ctrl => self.move_by(-1),
            KeyCode::Char('n') if ctrl => self.move_by(1),
            KeyCode::PageUp => self.move_by(-(self.page as isize)),
            KeyCode::PageDown => self.move_by(self.page as isize),
            KeyCode::Home | KeyCode::Char('g') => self.cursor = 0,
            KeyCode::End | KeyCode::Char('G') => self.cursor = self.rows.len().saturating_sub(1),
            KeyCode::Left | KeyCode::Char('h') => self.left(),
            KeyCode::Right | KeyCode::Char('l') | KeyCode::Enter => {
                if let Some(row) = self.rows.get(self.cursor) {
                    if row.is_dir {
                        self.toggle(Some(true));
                    } else {
                        return Action::Open(row.path.clone());
                    }
                }
            }
            KeyCode::Char(' ') => self.toggle(None),
            KeyCode::Char('.') => {
                self.opts.hidden = !self.opts.hidden;
                self.refresh();
            }
            KeyCode::Char('R') => self.refresh(),
            KeyCode::Tab => {
                if let Some(path) = self.current().map(Path::to_path_buf) {
                    if !self.marked.remove(&path) {
                        self.marked.insert(path);
                    }
                    self.move_by(1);
                }
            }
            KeyCode::Char('a') => self.mode = Mode::Prompt(PromptKind::Create(self.target_dir()), Input::default()),
            KeyCode::Char('r') => {
                if let Some(row) = self.rows.get(self.cursor) {
                    self.mode = Mode::Prompt(PromptKind::Rename(row.path.clone()), Input::new(row.name.clone()));
                }
            }
            KeyCode::Char(c @ ('d' | 'D')) => {
                let targets = self.targets();
                if !targets.is_empty() {
                    self.mode = Mode::Confirm(if c == 'd' { ConfirmKind::Trash } else { ConfirmKind::Delete }, targets);
                }
            }
            KeyCode::Char(c @ ('y' | 'x')) => {
                let paths = self.targets();
                if !paths.is_empty() {
                    let n = paths.len();
                    self.clip = Some(Clip { paths, cut: c == 'x' });
                    self.marked.clear();
                    self.say(format!("{} {n} item{}", if c == 'x' { "cut" } else { "yanked" }, if n == 1 { "" } else { "s" }), false);
                }
            }
            KeyCode::Char('p') => return self.paste(),
            KeyCode::Char('/') => return Action::Search(Search::Files),
            KeyCode::Char('S') => return Action::Search(Search::Grep),
            KeyCode::Char('B') => {
                let t = self.targets();
                if !t.is_empty() {
                    return Action::BulkRename(t);
                }
            }
            KeyCode::Char('O') => {
                if let Some(row) = self.rows.get(self.cursor) {
                    self.mode = Mode::Prompt(PromptKind::OpenWith(row.path.clone()), Input::default());
                }
            }
            KeyCode::Char('L') => {
                if let Some(row) = self.rows.get(self.cursor).filter(|r| r.is_dir) {
                    let dir = row.path.clone();
                    self.set_root(dir);
                }
            }
            KeyCode::Char('H') => {
                if let Some(parent) = self.root.parent().map(Path::to_path_buf) {
                    let old = self.root.clone();
                    self.set_root(parent);
                    self.reveal(&old);
                }
            }
            _ => {}
        }
        Action::None
    }

    fn prompt_key(&mut self, kind: PromptKind, mut input: Input, ev: &Event, key: &KeyEvent) -> Action {
        match key.code {
            KeyCode::Esc => Action::None,
            KeyCode::Enter => {
                let value = input.value().to_string();
                match kind {
                    PromptKind::Create(dir) => self.create(&dir, &value),
                    PromptKind::Rename(from) => self.rename(&from, &value),
                    PromptKind::OpenWith(path) => Action::OpenWith(path, value),
                }
            }
            _ => {
                input.handle_event(ev);
                self.mode = Mode::Prompt(kind, input);
                Action::None
            }
        }
    }

    fn confirm_key(&mut self, kind: ConfirmKind, targets: Vec<PathBuf>, key: &KeyEvent) -> Action {
        match key.code {
            KeyCode::Char('y' | 'Y') | KeyCode::Enter => self.delete(kind, targets),
            _ => Action::None,
        }
    }

    fn create(&mut self, dir: &Path, name: &str) -> Action {
        match ops::create(dir, name) {
            Ok((path, is_dir)) => {
                self.say(format!("created {}", name.trim_end_matches('/')), false);
                self.reveal(&path);
                Action::Created(path, is_dir)
            }
            Err(e) => {
                self.say(e.to_string(), true);
                Action::None
            }
        }
    }

    fn rename(&mut self, from: &Path, name: &str) -> Action {
        match ops::rename(from, name) {
            Ok(to) if to == from => Action::None,
            Ok(to) => {
                self.remap_expanded(from, &to);
                self.marked.clear();
                self.say(format!("renamed to {name}"), false);
                self.reveal(&to);
                Action::Moved(vec![(from.to_path_buf(), to)])
            }
            Err(e) => {
                self.say(e.to_string(), true);
                Action::None
            }
        }
    }

    /// Keep folders open across a rename or move.
    fn remap_expanded(&mut self, from: &Path, to: &Path) {
        let moved: Vec<PathBuf> = self.expanded.iter().filter(|p| p.starts_with(from)).cloned().collect();
        for old in moved {
            self.expanded.remove(&old);
            if let Ok(rest) = old.strip_prefix(from) {
                self.expanded.insert(to.join(rest));
            }
        }
    }

    fn delete(&mut self, kind: ConfirmKind, targets: Vec<PathBuf>) -> Action {
        let result = match kind {
            ConfirmKind::Trash => ops::trash(&targets),
            ConfirmKind::Delete => targets.iter().try_for_each(|p| ops::remove(p)).map_err(|e| e.to_string()),
        };
        match result {
            Ok(()) => {
                let n = targets.len();
                self.say(format!("{} {n} item{}", if kind == ConfirmKind::Trash { "trashed" } else { "deleted" }, if n == 1 { "" } else { "s" }), false);
                self.marked.clear();
                self.refresh();
                Action::Deleted(targets)
            }
            Err(e) => {
                self.say(e, true);
                self.refresh();
                Action::None
            }
        }
    }

    fn paste(&mut self) -> Action {
        let Some(clip) = self.clip.take() else {
            self.say("nothing to paste (yank with y, cut with x)", true);
            return Action::None;
        };
        let dir = self.target_dir();
        let (mut moved, mut done, mut failed) = (Vec::new(), 0usize, Vec::new());
        for src in &clip.paths {
            let Some(name) = src.file_name() else { continue };
            let mut dest = dir.join(name);
            if clip.cut && dest == *src {
                continue; // cut and pasted where it already is
            }
            dest = ops::unique(dest);
            let result = if clip.cut { ops::move_to(src, &dest) } else { ops::copy(src, &dest) };
            match result {
                Ok(()) => {
                    done += 1;
                    if clip.cut {
                        self.remap_expanded(src, &dest);
                        moved.push((src.clone(), dest));
                    }
                }
                Err(e) => failed.push(format!("{}: {e}", name.to_string_lossy())),
            }
        }
        if !clip.cut {
            self.clip = Some(clip); // a yank can be pasted again
        }
        self.expanded.insert(dir);
        self.refresh();
        if failed.is_empty() {
            self.say(format!("pasted {done} item{}", if done == 1 { "" } else { "s" }), false);
        } else {
            self.say(failed.join("; "), true);
        }
        if moved.is_empty() { Action::None } else { Action::Moved(moved) }
    }

    fn git_state(&self, row: &Row) -> Option<(char, Kind)> {
        let (repo, status) = self.git.as_ref()?;
        let rela = repo.relative(&row.path)?;
        if row.is_dir {
            status.dir(&rela).map(|k| ('•', k))
        } else {
            status.get(&rela)?.sign()
        }
    }

    fn git_color(theme: &Theme, kind: Kind) -> Color {
        let g = &theme.colors.git;
        match kind {
            Kind::Added => g.added,
            Kind::Modified | Kind::Typechange => g.modified,
            Kind::Deleted => g.deleted,
            Kind::Renamed => g.renamed,
            Kind::Untracked => g.untracked,
            Kind::Conflict => g.conflict,
        }
        .into()
    }

    /// The footer: a prompt, a confirmation question, or the last message.
    fn footer(&self, theme: &Theme) -> Option<Line<'static>> {
        let c = &theme.colors;
        match &self.mode {
            Mode::Prompt(kind, input) => {
                let label = match kind {
                    PromptKind::Create(_) => "new: ",
                    PromptKind::Rename(_) => "rename: ",
                    PromptKind::OpenWith(_) => "open with: ",
                };
                Some(Line::from(vec![
                    Span::styled(label, Style::new().fg(c.accent.into())),
                    Span::styled(input.value().to_string(), Style::new().fg(c.fg.into())),
                ]))
            }
            Mode::Confirm(kind, targets) => {
                let what = if targets.len() == 1 {
                    targets[0].file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default()
                } else {
                    format!("{} items", targets.len())
                };
                let verb = if *kind == ConfirmKind::Trash { "Trash" } else { "Delete permanently" };
                Some(Line::from(Span::styled(format!("{verb} {what}? (y/n)"), Style::new().fg(c.warning.into()))))
            }
            Mode::Normal => self.message.as_ref().map(|(m, err)| Line::from(Span::styled(m.clone(), Style::new().fg(if *err { c.error } else { c.muted }.into())))),
        }
    }

    /// Draw the panel in `area`; `focused` colors the border like any focused pane.
    pub fn render(&mut self, area: Rect, buf: &mut Buffer, theme: &Theme, focused: bool) {
        let c = &theme.colors;
        let title = self.root.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_else(|| "/".into());
        let pane = Pane::new(theme).title(&title).focused(focused);
        let mut inner = pane.inner(area);
        pane.render(area, buf);
        if inner.height == 0 || inner.width < 4 {
            return;
        }

        if let Some(line) = self.footer(theme) {
            let y = inner.bottom() - 1;
            let footer_area = Rect { y, height: 1, ..inner };
            Paragraph::new(line).render(footer_area, buf);
            if let Mode::Prompt(kind, input) = &self.mode {
                let label = match kind {
                    PromptKind::Create(_) => 5,
                    PromptKind::Rename(_) => 8,
                    PromptKind::OpenWith(_) => 11,
                };
                let x = inner.x + label + input.visual_cursor() as u16;
                if x < inner.right() {
                    if let Some(cell) = buf.cell_mut((x, y)) {
                        cell.set_style(Style::new().add_modifier(Modifier::REVERSED));
                    }
                }
            }
            inner.height -= 1;
            if inner.height == 0 {
                return;
            }
        }

        self.page = usize::from(inner.height).max(1);
        if self.cursor < self.offset {
            self.offset = self.cursor;
        } else if self.cursor >= self.offset + self.page {
            self.offset = self.cursor + 1 - self.page;
        }

        for (i, row) in self.rows.iter().enumerate().skip(self.offset).take(self.page) {
            let y = inner.y + (i - self.offset) as u16;
            let area = Rect { y, height: 1, ..inner };
            let selected = i == self.cursor;
            let base = if selected && focused { Style::new().bg(c.selection.into()).add_modifier(Modifier::BOLD) } else { Style::new() };
            buf.set_style(area, base);

            let git = self.git_state(row);
            let color = git.map(|(_, k)| Self::git_color(theme, k)).unwrap_or(if row.is_dir { c.accent.into() } else { c.fg.into() });
            let mut name_style = Style::new().fg(color);
            if row.is_dir {
                name_style = name_style.add_modifier(Modifier::BOLD);
            }
            // Marked rows: yellow (yazi's selected color) and underlined (no column is spent on a marker).
            if self.marked.contains(&row.path) {
                name_style = name_style.fg(c.warning.into()).add_modifier(Modifier::UNDERLINED);
            }
            if self.clip.as_ref().is_some_and(|k| k.cut && k.paths.contains(&row.path)) {
                name_style = name_style.add_modifier(Modifier::DIM);
            }
            let icon = if row.is_dir {
                ui::icons::dir(&row.name, self.expanded.contains(&row.path))
            } else {
                ui::icons::file(&row.name, is_executable(&row.path))
            };
            let line = Line::from(vec![
                Span::raw(" ".repeat(usize::from(row.depth) * 2)),
                Span::styled(format!("{} ", icon.glyph), Style::new().fg(icon.color)),
                Span::styled(row.name.clone(), name_style),
            ]);
            Paragraph::new(line).style(base).render(area, buf);

            if let Some((ch, kind)) = git {
                let x = inner.right().saturating_sub(1);
                buf.set_string(x, y, ch.to_string(), base.fg(Self::git_color(theme, kind)));
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::process::Command;

    fn tree(name: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("files-test-{}-{name}", std::process::id()));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(d.join("src/deep")).unwrap();
        fs::create_dir_all(d.join("docs")).unwrap();
        fs::write(d.join("README.md"), "r").unwrap();
        fs::write(d.join(".hidden"), "h").unwrap();
        fs::write(d.join("src/main.rs"), "m").unwrap();
        fs::write(d.join("src/deep/inner.txt"), "i").unwrap();
        d.canonicalize().unwrap()
    }

    fn key(c: KeyCode) -> Event {
        Event::Key(KeyEvent::new(c, KeyModifiers::NONE))
    }

    fn names(p: &Panel) -> Vec<String> {
        p.rows.iter().map(|r| format!("{}{}", "  ".repeat(r.depth.into()), r.name)).collect()
    }

    fn panel(d: &Path) -> Panel {
        Panel::new(d, PanelOptions { hidden: false, git: false })
    }

    #[test]
    fn lists_dirs_first_and_hides_dotfiles() {
        let p = panel(&tree("list"));
        assert_eq!(names(&p), vec!["docs", "src", "README.md"]);
    }

    #[test]
    fn expand_collapse_and_left_navigation() {
        let mut p = panel(&tree("expand"));
        p.handle_event(&key(KeyCode::Down)); // src
        p.handle_event(&key(KeyCode::Right));
        assert_eq!(names(&p), vec!["docs", "src", "  deep", "  main.rs", "README.md"]);
        p.handle_event(&key(KeyCode::Down)); // deep
        p.handle_event(&key(KeyCode::Right));
        assert!(names(&p).contains(&"    inner.txt".to_string()));
        // h on an open folder collapses it; on a file or closed folder it jumps to the parent.
        p.handle_event(&key(KeyCode::Char('h')));
        assert!(!names(&p).contains(&"    inner.txt".to_string()));
        p.handle_event(&key(KeyCode::Char('h')));
        assert_eq!(p.current().unwrap().file_name().unwrap(), "src");
        p.handle_event(&key(KeyCode::Char('h')));
        assert_eq!(names(&p), vec!["docs", "src", "README.md"]);
    }

    #[test]
    fn enter_opens_files_and_toggles_hidden() {
        let d = tree("open");
        let mut p = panel(&d);
        p.handle_event(&key(KeyCode::Char('G'))); // README.md
        assert_eq!(p.handle_event(&key(KeyCode::Enter)), Action::Open(d.join("README.md")));
        p.handle_event(&key(KeyCode::Char('.')));
        assert!(names(&p).contains(&".hidden".to_string()));
        p.handle_event(&key(KeyCode::Char('.')));
        assert!(!names(&p).contains(&".hidden".to_string()));
        assert_eq!(p.handle_event(&key(KeyCode::Esc)), Action::Close);
    }

    #[test]
    fn reveal_expands_to_the_file_and_refresh_keeps_the_cursor() {
        let d = tree("reveal");
        let mut p = panel(&d);
        p.reveal(&d.join("src/deep/inner.txt"));
        assert_eq!(p.current().unwrap(), d.join("src/deep/inner.txt"));
        fs::write(d.join("src/zzz.txt"), "z").unwrap();
        p.refresh();
        assert!(names(&p).iter().any(|n| n.contains("zzz.txt")));
        assert_eq!(p.current().unwrap(), d.join("src/deep/inner.txt"));
        // Revealing something outside the root does nothing.
        p.reveal(Path::new("/etc/hostname"));
        assert_eq!(p.current().unwrap(), d.join("src/deep/inner.txt"));
    }

    #[test]
    fn respects_gitignore_and_shows_git_state() {
        let d = tree("git");
        let git = |args: &[&str]| {
            assert!(Command::new("git")
                .args(["-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false"])
                .args(args)
                .current_dir(&d)
                .env("GIT_CONFIG_GLOBAL", "/dev/null")
                .env("GIT_CONFIG_SYSTEM", "/dev/null")
                .status()
                .unwrap()
                .success());
        };
        git(&["init", "-q", "-b", "main"]);
        fs::write(d.join(".gitignore"), "docs/\n").unwrap();
        git(&["add", "README.md", "src", ".gitignore"]);
        git(&["commit", "-q", "-m", "i"]);
        fs::write(d.join("README.md"), "changed").unwrap();
        fs::write(d.join("src/new.rs"), "n").unwrap();

        let mut p = Panel::new(&d, PanelOptions::default());
        assert!(!names(&p).contains(&"docs".to_string()), "gitignored folder is hidden: {:?}", names(&p));

        let area = Rect::new(0, 0, 30, 8);
        let mut buf = Buffer::empty(area);
        p.render(area, &mut buf, &Theme::default(), true);
        let row = |y: u16| (0..30).map(|x| buf[(x, y)].symbol().to_string()).collect::<String>();
        let text: Vec<String> = (0..8).map(row).collect();
        // src has an untracked file beneath it (dot), README.md is modified (M).
        assert!(text.iter().any(|l| l.contains("src") && l.trim_end().trim_end_matches('│').trim_end().ends_with('•')), "{text:?}");
        assert!(text.iter().any(|l| l.contains("README.md") && l.contains('M')), "{text:?}");
    }

    #[test]
    fn renders_a_pane_with_the_root_name_and_scrolls() {
        let d = tree("render");
        for i in 0..30 {
            fs::write(d.join(format!("file{i:02}.txt")), "x").unwrap();
        }
        let mut p = panel(&d);
        let area = Rect::new(0, 0, 30, 8);
        let mut buf = Buffer::empty(area);
        p.render(area, &mut buf, &Theme::default(), true);
        let all: String = (0..8).map(|y| (0..30).map(|x| buf[(x, y)].symbol().to_string()).collect::<String>() + "\n").collect();
        assert!(all.contains("files-test-") && all.contains("docs"), "{all}");
        p.handle_event(&key(KeyCode::Char('G')));
        let mut buf = Buffer::empty(area);
        p.render(area, &mut buf, &Theme::default(), true);
        let all: String = (0..8).map(|y| (0..30).map(|x| buf[(x, y)].symbol().to_string()).collect::<String>() + "\n").collect();
        assert!(all.contains("file29.txt") && !all.contains("docs"), "{all}");
    }

    fn type_text(p: &mut Panel, s: &str) {
        for c in s.chars() {
            p.handle_event(&key(KeyCode::Char(c)));
        }
    }

    fn cursor_on(p: &mut Panel, name: &str) {
        let i = p.rows.iter().position(|r| r.name == name).unwrap_or_else(|| panic!("{name} in {:?}", names(p)));
        p.cursor = i;
    }

    #[test]
    fn a_creates_in_the_folder_under_the_cursor_and_reports_it() {
        let d = tree("create");
        let mut p = panel(&d);
        cursor_on(&mut p, "src");
        p.handle_event(&key(KeyCode::Char('a')));
        type_text(&mut p, "new.rs");
        assert_eq!(p.handle_event(&key(KeyCode::Enter)), Action::Created(d.join("src/new.rs"), false));
        assert!(d.join("src/new.rs").is_file());
        // The folder opened and the cursor is on the new file.
        assert_eq!(p.current().unwrap(), d.join("src/new.rs"));
        // On a file the new item goes next to it; a trailing slash makes a folder.
        p.handle_event(&key(KeyCode::Char('a')));
        type_text(&mut p, "pkg/mod/");
        assert_eq!(p.handle_event(&key(KeyCode::Enter)), Action::Created(d.join("src/pkg/mod"), true));
        assert!(d.join("src/pkg/mod").is_dir());
    }

    #[test]
    fn creating_something_that_exists_shows_an_error_and_esc_cancels_the_prompt() {
        let d = tree("exists");
        let mut p = panel(&d);
        cursor_on(&mut p, "README.md");
        p.handle_event(&key(KeyCode::Char('a')));
        type_text(&mut p, "README.md");
        assert_eq!(p.handle_event(&key(KeyCode::Enter)), Action::None);
        assert!(p.message.as_ref().is_some_and(|(m, err)| *err && m.contains("already exists")), "{:?}", p.message);
        p.handle_event(&key(KeyCode::Char('a')));
        type_text(&mut p, "abc");
        assert_eq!(p.handle_event(&key(KeyCode::Esc)), Action::None);
        assert!(matches!(p.mode, Mode::Normal));
        assert!(!d.join("abc").exists());
        // Esc in normal mode still closes the panel.
        assert_eq!(p.handle_event(&key(KeyCode::Esc)), Action::Close);
    }

    #[test]
    fn r_renames_with_the_name_prefilled_and_keeps_folders_open() {
        let d = tree("rename");
        let mut p = panel(&d);
        cursor_on(&mut p, "src");
        p.handle_event(&key(KeyCode::Right)); // open src
        cursor_on(&mut p, "src");
        p.handle_event(&key(KeyCode::Char('r')));
        for _ in 0..3 {
            p.handle_event(&key(KeyCode::Backspace));
        }
        type_text(&mut p, "lib");
        assert_eq!(p.handle_event(&key(KeyCode::Enter)), Action::Moved(vec![(d.join("src"), d.join("lib"))]));
        assert!(d.join("lib/main.rs").is_file() && !d.join("src").exists());
        assert!(names(&p).contains(&"  main.rs".to_string()), "still expanded: {:?}", names(&p));
        assert_eq!(p.current().unwrap(), d.join("lib"));
    }

    #[test]
    fn d_asks_first_and_deletes_the_marked_items_only_on_yes() {
        let d = tree("delete");
        let mut p = panel(&d);
        cursor_on(&mut p, "docs");
        p.handle_event(&key(KeyCode::Tab)); // mark docs, cursor moves down
        cursor_on(&mut p, "README.md");
        p.handle_event(&key(KeyCode::Tab)); // mark README.md
        assert_eq!(p.marked.len(), 2);
        p.handle_event(&key(KeyCode::Char('D'))); // permanent delete (the trash is not used in tests)
        assert!(matches!(p.mode, Mode::Confirm(ConfirmKind::Delete, _)));
        assert_eq!(p.handle_event(&key(KeyCode::Char('n'))), Action::None);
        assert!(d.join("docs").exists() && d.join("README.md").exists());
        p.handle_event(&key(KeyCode::Char('D')));
        let got = p.handle_event(&key(KeyCode::Char('y')));
        assert_eq!(got, Action::Deleted(vec![d.join("README.md"), d.join("docs")]));
        assert!(!d.join("docs").exists() && !d.join("README.md").exists());
        assert!(p.marked.is_empty());
    }

    #[test]
    fn y_then_p_copies_and_x_then_p_moves_with_unique_names() {
        let d = tree("paste");
        let mut p = panel(&d);
        // Copy README.md into docs/, twice: the second one gets a new name.
        cursor_on(&mut p, "README.md");
        p.handle_event(&key(KeyCode::Char('y')));
        cursor_on(&mut p, "docs");
        assert_eq!(p.handle_event(&key(KeyCode::Char('p'))), Action::None);
        p.handle_event(&key(KeyCode::Char('p')));
        assert!(d.join("docs/README.md").is_file() && d.join("docs/README copy.md").is_file());
        assert!(d.join("README.md").is_file(), "a copy keeps the original");
        // Cut src/main.rs and paste it into docs/: reported as a move, open folders follow.
        cursor_on(&mut p, "src");
        p.handle_event(&key(KeyCode::Right));
        cursor_on(&mut p, "main.rs");
        p.handle_event(&key(KeyCode::Char('x')));
        cursor_on(&mut p, "docs");
        let got = p.handle_event(&key(KeyCode::Char('p')));
        assert_eq!(got, Action::Moved(vec![(d.join("src/main.rs"), d.join("docs/main.rs"))]));
        assert!(!d.join("src/main.rs").exists() && d.join("docs/main.rs").is_file());
        // The cut clipboard is spent.
        p.handle_event(&key(KeyCode::Char('p')));
        assert!(p.message.as_ref().is_some_and(|(m, err)| *err && m.contains("nothing to paste")), "{:?}", p.message);
    }

    #[test]
    fn footer_shows_the_prompt_and_messages_in_the_render() {
        let d = tree("footer");
        let mut p = panel(&d);
        let area = Rect::new(0, 0, 40, 8);
        let draw = |p: &mut Panel| {
            let mut b = Buffer::empty(area);
            p.render(area, &mut b, &Theme::default(), true);
            (0..8).map(|y| (0..40).map(|x| b[(x, y)].symbol().to_string()).collect::<String>() + "\n").collect::<String>()
        };
        p.handle_event(&key(KeyCode::Char('a')));
        type_text(&mut p, "foo");
        assert!(draw(&mut p).contains("new: foo"));
        p.handle_event(&key(KeyCode::Esc));
        cursor_on(&mut p, "README.md");
        p.handle_event(&key(KeyCode::Char('D')));
        assert!(draw(&mut p).contains("Delete permanently README.md? (y/n)"));
        p.handle_event(&key(KeyCode::Char('n')));
        p.handle_event(&key(KeyCode::Char('y')));
        p.handle_event(&key(KeyCode::Char('p')));
        assert!(draw(&mut p).contains("pasted 1 item"));
    }
}
