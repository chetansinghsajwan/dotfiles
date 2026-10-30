use git_core::{CommitInfo, RefInfo, RefKind, Repo, StashInfo};
use git_panel::{Action as PanelAction, Panel};
use ratatui::buffer::Buffer;
use ratatui::crossterm::event::{Event, KeyCode, KeyEvent, KeyEventKind, KeyModifiers};
use ratatui::layout::{Constraint, Layout, Rect};
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Paragraph, Widget};
use std::path::{Path, PathBuf};
use tui_input::Input;
use tui_input::backend::crossterm::EventHandler;
use ui::{Pane, Theme};

/// How many commits the log pane loads.
const LOG_LIMIT: usize = 500;

/// What the host should do after an event.
#[derive(Debug, PartialEq, Eq)]
pub enum Quit {
    No,
    Yes,
    /// Open this file in the editor (the host suspends the screen), then call `edited`.
    Edit(PathBuf),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Focus {
    Files,
    Branches,
    Commits,
    Stashes,
}

const ORDER: [Focus; 4] = [Focus::Files, Focus::Branches, Focus::Commits, Focus::Stashes];

enum PromptKind {
    NewBranch,
    NewStash,
}

enum Confirm {
    DeleteBranch { name: String, force: bool },
    Merge(String),
    DropStash(usize),
}

enum Mode {
    Normal,
    Prompt(PromptKind, Input),
    Confirm(Confirm),
}

#[derive(Default, Clone, Copy)]
struct ListState {
    cursor: usize,
    offset: usize,
}

struct Preview {
    key: (Focus, String, u16),
    lines: Vec<Line<'static>>,
}

pub struct App {
    root: PathBuf,
    repo: Repo,
    theme: Theme,
    files: Panel,
    branches: Vec<RefInfo>,
    commits: Vec<CommitInfo>,
    stashes: Vec<StashInfo>,
    /// Cursor and scroll of the branches, commits and stashes panes.
    lists: [ListState; 3],
    focus: Focus,
    mode: Mode,
    message: Option<(String, bool)>,
    preview: Option<Preview>,
    pscroll: usize,
    pheight: usize,
}

impl App {
    /// The screen for the repository containing `dir`; `None` if there is none.
    pub fn new(dir: &Path) -> Option<App> {
        let repo = Repo::discover(dir)?;
        let root = repo.root().to_path_buf();
        let mut files = Panel::new(dir)?;
        files.set_title("Files");
        let mut app = App {
            root,
            repo,
            theme: Theme::load(),
            files,
            branches: Vec::new(),
            commits: Vec::new(),
            stashes: Vec::new(),
            lists: [ListState::default(); 3],
            focus: Focus::Files,
            mode: Mode::Normal,
            message: None,
            preview: None,
            pscroll: 0,
            pheight: 10,
        };
        app.reload_all();
        Some(app)
    }

    // ---- data -----------------------------------------------------------

    fn reload_history(&mut self) {
        if let Some(repo) = Repo::discover(&self.root) {
            self.repo = repo;
        }
        let mut refs = self.repo.refs().unwrap_or_default();
        // Local branches first (the checked-out one on top), then remotes, then tags.
        let rank = |r: &RefInfo| match r.kind {
            RefKind::Branch => 0,
            RefKind::Remote => 1,
            RefKind::Tag => 2,
        };
        refs.sort_by(|a, b| rank(a).cmp(&rank(b)).then(b.is_head.cmp(&a.is_head)).then(b.time.cmp(&a.time)));
        self.branches = refs;
        self.commits = self.repo.commits(LOG_LIMIT).unwrap_or_default();
        self.stashes = self.repo.stashes().unwrap_or_default();
        for (i, len) in [self.branches.len(), self.commits.len(), self.stashes.len()].into_iter().enumerate() {
            self.lists[i].cursor = self.lists[i].cursor.min(len.saturating_sub(1));
        }
        self.preview = None;
    }

    fn reload_all(&mut self) {
        self.files.refresh();
        self.reload_history();
    }

    /// Call after the editor the host opened for `Quit::Edit` returns.
    pub fn edited(&mut self, ok: bool) {
        self.reload_all();
        if !ok {
            self.say("the editor exited with an error", true);
        }
    }

    fn say(&mut self, msg: impl Into<String>, error: bool) {
        self.message = Some((msg.into(), error));
    }

    fn list_index(focus: Focus) -> Option<usize> {
        match focus {
            Focus::Files => None,
            Focus::Branches => Some(0),
            Focus::Commits => Some(1),
            Focus::Stashes => Some(2),
        }
    }

    fn len(&self, focus: Focus) -> usize {
        match focus {
            Focus::Files => 0,
            Focus::Branches => self.branches.len(),
            Focus::Commits => self.commits.len(),
            Focus::Stashes => self.stashes.len(),
        }
    }

    /// Run a git change, report the outcome, reload everything.
    fn run(&mut self, ok: String, f: impl FnOnce(&Repo) -> Result<(), git_core::Error>) {
        match f(&self.repo) {
            Ok(()) => self.say(ok, false),
            Err(e) => self.say(e.to_string(), true),
        }
        self.reload_all();
    }

    // ---- events ---------------------------------------------------------

    pub fn handle_event(&mut self, ev: &Event) -> Quit {
        let Event::Key(key @ KeyEvent { kind, .. }) = ev else { return Quit::No };
        if *kind == KeyEventKind::Release {
            return Quit::No;
        }
        match std::mem::replace(&mut self.mode, Mode::Normal) {
            Mode::Prompt(kind, input) => {
                self.prompt_key(kind, input, ev, key);
                return Quit::No;
            }
            Mode::Confirm(c) => {
                self.confirm_key(c, key);
                return Quit::No;
            }
            Mode::Normal => {}
        }
        if self.focus == Focus::Files && self.files.is_typing() {
            return self.files_event(ev);
        }
        let ctrl = key.modifiers.contains(KeyModifiers::CONTROL);
        self.message = None;
        match key.code {
            KeyCode::Char('q') => return Quit::Yes,
            KeyCode::Char('c') if ctrl => return Quit::Yes,
            KeyCode::Tab => {
                self.focus_by(1);
                return Quit::No;
            }
            KeyCode::BackTab => {
                self.focus_by(-1);
                return Quit::No;
            }
            KeyCode::Char(c @ '1'..='4') => {
                self.focus = ORDER[c as usize - '1' as usize];
                self.pscroll = 0;
                return Quit::No;
            }
            _ => {}
        }
        if self.focus == Focus::Files {
            return self.files_event(ev);
        }
        self.list_key(key);
        Quit::No
    }

    fn focus_by(&mut self, delta: isize) {
        let at = ORDER.iter().position(|f| *f == self.focus).unwrap_or(0) as isize;
        self.focus = ORDER[(at + delta).rem_euclid(ORDER.len() as isize) as usize];
        self.pscroll = 0;
    }

    fn files_event(&mut self, ev: &Event) -> Quit {
        match self.files.handle_event(ev) {
            PanelAction::Close => Quit::Yes,
            PanelAction::Open(path) => Quit::Edit(path),
            PanelAction::Changed => {
                self.reload_history();
                Quit::No
            }
            PanelAction::None => Quit::No,
        }
    }

    fn list_key(&mut self, key: &KeyEvent) {
        let ctrl = key.modifiers.contains(KeyModifiers::CONTROL);
        let focus = self.focus;
        let Some(li) = Self::list_index(focus) else { return };
        let last = self.len(focus).saturating_sub(1);
        let st = &mut self.lists[li];
        match key.code {
            KeyCode::Esc => {
                self.focus = Focus::Files;
                return;
            }
            KeyCode::Down | KeyCode::Char('j') => st.cursor = (st.cursor + 1).min(last),
            KeyCode::Up | KeyCode::Char('k') => st.cursor = st.cursor.saturating_sub(1),
            KeyCode::Char('n') if ctrl => st.cursor = (st.cursor + 1).min(last),
            KeyCode::Char('p') if ctrl => st.cursor = st.cursor.saturating_sub(1),
            KeyCode::PageDown => st.cursor = (st.cursor + 10).min(last),
            KeyCode::PageUp => st.cursor = st.cursor.saturating_sub(10),
            KeyCode::Home | KeyCode::Char('g') => st.cursor = 0,
            KeyCode::End | KeyCode::Char('G') => st.cursor = last,
            KeyCode::Char('d') if ctrl => {
                self.pscroll += (self.pheight / 2).max(1);
                return;
            }
            KeyCode::Char('u') if ctrl => {
                self.pscroll = self.pscroll.saturating_sub((self.pheight / 2).max(1));
                return;
            }
            _ => {
                self.focus_action(key);
                return;
            }
        }
        self.pscroll = 0;
    }

    /// The keys that act on the highlighted branch or stash.
    fn focus_action(&mut self, key: &KeyEvent) {
        match self.focus {
            Focus::Branches => {
                let Some(b) = self.branches.get(self.lists[0].cursor).cloned() else {
                    if key.code == KeyCode::Char('n') {
                        self.mode = Mode::Prompt(PromptKind::NewBranch, Input::default());
                    }
                    return;
                };
                match key.code {
                    KeyCode::Enter | KeyCode::Char(' ') => {
                        if b.is_head {
                            self.say(format!("already on {}", b.name), false);
                        } else {
                            let (name, kind) = (b.name.clone(), b.kind);
                            self.run(format!("switched to {}", b.name), move |r| r.checkout_ref(&name, kind));
                        }
                    }
                    KeyCode::Char('n') => self.mode = Mode::Prompt(PromptKind::NewBranch, Input::default()),
                    KeyCode::Char(c @ ('d' | 'D')) => {
                        if b.kind != RefKind::Branch || b.is_head {
                            self.say("only a local branch that is not checked out can be deleted", true);
                        } else {
                            self.mode = Mode::Confirm(Confirm::DeleteBranch { name: b.name, force: c == 'D' });
                        }
                    }
                    KeyCode::Char('M') => {
                        if b.is_head {
                            self.say("cannot merge a branch into itself", true);
                        } else {
                            self.mode = Mode::Confirm(Confirm::Merge(b.name));
                        }
                    }
                    _ => {}
                }
            }
            Focus::Stashes => {
                let cur = self.stashes.get(self.lists[2].cursor).map(|s| s.index);
                match (key.code, cur) {
                    (KeyCode::Char('n'), _) => self.mode = Mode::Prompt(PromptKind::NewStash, Input::default()),
                    (KeyCode::Char('a') | KeyCode::Enter, Some(i)) => self.run(format!("applied stash@{{{i}}}"), move |r| r.stash_apply(i)),
                    (KeyCode::Char('p'), Some(i)) => self.run(format!("popped stash@{{{i}}}"), move |r| r.stash_pop(i)),
                    (KeyCode::Char('d'), Some(i)) => self.mode = Mode::Confirm(Confirm::DropStash(i)),
                    _ => {}
                }
            }
            _ => {}
        }
    }

    fn prompt_key(&mut self, kind: PromptKind, mut input: Input, ev: &Event, key: &KeyEvent) {
        match key.code {
            KeyCode::Esc => {}
            KeyCode::Enter => {
                let value = input.value().to_string();
                match kind {
                    PromptKind::NewBranch => {
                        let v = value.clone();
                        self.run(format!("created {value}"), move |r| r.create_branch(&v));
                    }
                    PromptKind::NewStash => {
                        let v = value.clone();
                        self.run("stashed the changes".to_string(), move |r| r.stash_push(&v));
                    }
                }
            }
            _ => {
                input.handle_event(ev);
                self.mode = Mode::Prompt(kind, input);
            }
        }
    }

    fn confirm_key(&mut self, c: Confirm, key: &KeyEvent) {
        if !matches!(key.code, KeyCode::Char('y' | 'Y') | KeyCode::Enter) {
            return;
        }
        match c {
            Confirm::DeleteBranch { name, force } => {
                let n = name.clone();
                self.run(format!("deleted {name}"), move |r| r.delete_branch(&n, force));
            }
            Confirm::Merge(name) => {
                let n = name.clone();
                self.run(format!("merged {name}"), move |r| r.merge(&n));
            }
            Confirm::DropStash(i) => self.run(format!("dropped stash@{{{i}}}"), move |r| r.stash_drop(i)),
        }
    }

    // ---- drawing --------------------------------------------------------

    pub fn render(&mut self, area: Rect, buf: &mut Buffer) {
        let theme = self.theme.clone();
        let body = Rect { height: area.height.saturating_sub(1), ..area };
        let status = Rect { y: area.bottom().saturating_sub(1), height: 1, ..area };
        let [left, right] = ui::layout::main_preview(&theme, body);

        // The focused pane takes the room; the others show a few rows.
        let constraints = ORDER.map(|f| if f == self.focus { Constraint::Min(7) } else { Constraint::Length(5) });
        let panes = Layout::vertical(constraints).split(left);
        self.files.render_compact(panes[0], buf, &theme, self.focus == Focus::Files);
        for (i, f) in [Focus::Branches, Focus::Commits, Focus::Stashes].into_iter().enumerate() {
            self.render_list(f, panes[i + 1], buf, &theme);
        }
        match self.focus {
            Focus::Files => self.files.render_preview_pane(right, buf, &theme),
            f => self.render_preview(f, right, buf, &theme),
        }
        self.render_status(status, buf, &theme);
    }

    fn render_list(&mut self, which: Focus, area: Rect, buf: &mut Buffer, theme: &Theme) {
        let (title, n) = match which {
            Focus::Branches => ("Branches", self.branches.len()),
            Focus::Commits => ("Commits", self.commits.len()),
            _ => ("Stashes", self.stashes.len()),
        };
        let focused = self.focus == which;
        let mut pane = Pane::new(theme).title(title).focused(focused);
        if let Some(icon) = ui::icons::for_title(title) {
            pane = pane.icon(icon);
        }
        let inner = pane.inner(area);
        pane.render(area, buf);
        if inner.height == 0 || inner.width < 4 {
            return;
        }
        let Some(li) = Self::list_index(which) else { return };
        if n == 0 {
            buf.set_string(inner.x + 1, inner.y, "nothing here", Style::new().fg(theme.colors.muted.into()));
            return;
        }
        let page = usize::from(inner.height);
        let st = &mut self.lists[li];
        if st.cursor < st.offset {
            st.offset = st.cursor;
        } else if st.cursor >= st.offset + page {
            st.offset = st.cursor + 1 - page;
        }
        let (cursor, offset) = (st.cursor, st.offset);
        let rows = ui::list::Rows::new(area, inner);
        for (row, i) in (offset..(offset + page).min(n)).enumerate() {
            let y = inner.y + row as u16;
            let base = ui::list::style(theme, i == cursor && focused, None);
            buf.set_style(rows.bar(y), base);
            let (left, right) = self.row(which, i, theme);
            let content = rows.content(y);
            let rw = right.chars().count() as u16;
            let room = if rw > 0 && content.width > rw + 12 { content.width - rw - 1 } else { content.width };
            Paragraph::new(left).style(base).render(Rect { width: room, ..content }, buf);
            if room < content.width {
                buf.set_string(content.right() - rw, y, right, base.fg(theme.colors.muted.into()));
            }
        }
    }

    /// The text of row `i`: the entry, and its age for the right edge.
    fn row(&self, which: Focus, i: usize, theme: &Theme) -> (Line<'static>, String) {
        let c = &theme.colors;
        let fg = Style::new().fg(c.fg.into());
        let muted = Style::new().fg(c.muted.into());
        match which {
            Focus::Branches => {
                let b = &self.branches[i];
                let name = if b.is_head {
                    Style::new().fg(c.success.into()).add_modifier(Modifier::BOLD)
                } else if b.kind == RefKind::Branch {
                    fg
                } else {
                    muted
                };
                (Line::from(Span::styled(b.name.clone(), name)), ago(b.time))
            }
            Focus::Commits => {
                let k = &self.commits[i];
                // `hash AB subject`: the author as two initials in a color of their own, like lazygit.
                let author = Span::styled(format!("{} ", initials(&k.author)), Style::new().fg(author_color(theme, &k.author)));
                (Line::from(vec![Span::styled(format!("{} ", k.short), muted), author, Span::styled(k.subject.clone(), fg)]), ago(k.time))
            }
            _ => {
                let s = &self.stashes[i];
                (Line::from(vec![Span::styled(format!("{} ", s.index), muted), Span::styled(s.message.clone(), fg)]), ago(s.time))
            }
        }
    }

    /// The rev to preview for the highlighted entry of a list pane.
    fn current_rev(&self, which: Focus) -> Option<String> {
        match which {
            Focus::Branches => self.branches.get(self.lists[0].cursor).map(|b| b.name.clone()),
            Focus::Commits => self.commits.get(self.lists[1].cursor).map(|c| c.oid.clone()),
            Focus::Stashes => self.stashes.get(self.lists[2].cursor).map(|s| format!("stash@{{{}}}", s.index)),
            Focus::Files => None,
        }
    }

    fn render_preview(&mut self, which: Focus, area: Rect, buf: &mut Buffer, theme: &Theme) {
        let rev = self.current_rev(which);
        let title = rev.clone().unwrap_or_default();
        let icon = match which {
            Focus::Branches => ui::icons::BRANCH,
            Focus::Stashes => ui::icons::STASH,
            _ => ui::icons::COMMIT,
        };
        let pane = Pane::new(theme).title(&title).icon(icon);
        let inner = pane.inner(area);
        pane.render(area, buf);
        let Some(rev) = rev else {
            self.preview = None;
            return;
        };
        if inner.width == 0 || inner.height == 0 {
            return;
        }
        let key = (which, rev.clone(), inner.width);
        if self.preview.as_ref().map(|p| &p.key) != Some(&key) {
            let opts = pv::Options { width: Some(inner.width), height: None, git: false, focus: None };
            let lines = match pv::preview_commit(&self.root, &rev, theme, &opts) {
                Ok(l) => l,
                Err(e) => vec![Line::from(Span::styled(e.to_string(), Style::new().fg(theme.colors.muted.into())))],
            };
            self.preview = Some(Preview { key, lines });
            self.pscroll = 0;
        }
        self.pheight = usize::from(inner.height);
        if let Some(p) = &self.preview {
            self.pscroll = self.pscroll.min(p.lines.len().saturating_sub(1));
            let shown: Vec<Line<'static>> = p.lines.iter().skip(self.pscroll).take(usize::from(inner.height)).cloned().collect();
            Paragraph::new(shown).render(inner, buf);
        }
    }

    fn render_status(&self, area: Rect, buf: &mut Buffer, theme: &Theme) {
        let c = &theme.colors;
        let line = match &self.mode {
            Mode::Prompt(kind, input) => {
                let label = match kind {
                    PromptKind::NewBranch => "new branch: ",
                    PromptKind::NewStash => "stash message: ",
                };
                ui::prompt::cursor(buf, area, label, input.visual_cursor());
                ui::prompt::line(theme, label, input.value())
            }
            Mode::Confirm(cf) => {
                let q = match cf {
                    Confirm::DeleteBranch { name, force } => format!("{} branch {name}? (y/n)", if *force { "Force-delete" } else { "Delete" }),
                    Confirm::Merge(name) => format!("Merge {name} into {}? (y/n)", self.files.branch()),
                    Confirm::DropStash(i) => format!("Drop stash@{{{i}}}? (y/n)"),
                };
                Line::from(Span::styled(q, Style::new().fg(c.warning.into())))
            }
            Mode::Normal => match &self.message {
                Some((m, err)) => Line::from(Span::styled(m.clone(), Style::new().fg(if *err { c.error } else { c.accent }.into()))),
                None => Line::from(Span::styled(self.hints(), Style::new().fg(c.muted.into()))),
            },
        };
        Paragraph::new(line).render(Rect { x: area.x + 1, width: area.width.saturating_sub(2), ..area }, buf);
    }

    fn hints(&self) -> &'static str {
        match self.focus {
            Focus::Files => "s stage  u unstage  a/A all  x discard  c commit  enter edit  tab/1-4 panes  q quit",
            Focus::Branches => "enter checkout  n new  d/D delete  M merge  ctrl-d/u scroll  tab/1-4 panes  q quit",
            Focus::Commits => "j/k move  ctrl-d/u scroll the diff  esc files  tab/1-4 panes  q quit",
            Focus::Stashes => "n new  a apply  p pop  d drop  ctrl-d/u scroll  tab/1-4 panes  q quit",
        }
    }
}

/// The author as two letters: the first letters of the first two words (`Chetan Singh Sajwan` ->
/// `CS`), or the first two letters of a single name (`root` -> `ro`).
fn initials(name: &str) -> String {
    let words: Vec<&str> = name.split_whitespace().collect();
    let letters: Vec<char> = match words.as_slice() {
        [] => vec!['?'],
        [one] => one.chars().take(2).collect(),
        [a, b, ..] => a.chars().take(1).chain(b.chars().take(1)).collect(),
    };
    letters.into_iter().collect()
}

/// A stable color per author, from the theme's accents, so one person always looks the same.
fn author_color(theme: &Theme, name: &str) -> ratatui::style::Color {
    let c = &theme.colors;
    let palette = [c.success, c.warning, c.info, c.accent, c.git.untracked, c.git.renamed, c.git.modified, c.git.conflict];
    let hash = name.bytes().fold(5381u32, |h, b| h.wrapping_mul(33).wrapping_add(u32::from(b)));
    palette[hash as usize % palette.len()].into()
}

/// `now`, `5m ago`, `4h ago`, ... for a commit time in seconds since the epoch.
fn ago(time: i64) -> String {
    let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(time);
    match (now - time).max(0) {
        0..60 => "now".into(),
        s @ 60..3600 => format!("{}m ago", s / 60),
        s @ 3600..86_400 => format!("{}h ago", s / 3600),
        s @ 86_400..2_592_000 => format!("{}d ago", s / 86_400),
        s @ 2_592_000..31_536_000 => format!("{}mo ago", s / 2_592_000),
        s => format!("{}y ago", s / 31_536_000),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::process::Command;
    use std::sync::Once;

    fn identity() {
        static ONCE: Once = Once::new();
        ONCE.call_once(|| {
            for (k, v) in [("GIT_AUTHOR_NAME", "t"), ("GIT_AUTHOR_EMAIL", "t@t"), ("GIT_COMMITTER_NAME", "t"), ("GIT_COMMITTER_EMAIL", "t@t"), ("GIT_CONFIG_GLOBAL", "/dev/null"), ("GIT_CONFIG_SYSTEM", "/dev/null")] {
                // SAFETY: set once, before any test starts git, to constants.
                unsafe { std::env::set_var(k, v) };
            }
        });
    }

    fn git(dir: &Path, args: &[&str]) {
        assert!(Command::new("git").args(args).current_dir(dir).status().unwrap().success(), "git {args:?}");
    }

    fn repo(name: &str) -> PathBuf {
        identity();
        let d = std::env::temp_dir().join(format!("git-ui-test-{}-{name}", std::process::id()));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(&d).unwrap();
        git(&d, &["init", "-q", "-b", "main"]);
        fs::write(d.join("a.txt"), "1\n2\n").unwrap();
        git(&d, &["add", "."]);
        git(&d, &["commit", "-qm", "first commit"]);
        git(&d, &["branch", "other"]);
        d.canonicalize().unwrap()
    }

    fn key(code: KeyCode) -> Event {
        Event::Key(KeyEvent::new(code, KeyModifiers::NONE))
    }

    fn press(app: &mut App, keys: &str) {
        for c in keys.chars() {
            assert_eq!(app.handle_event(&key(KeyCode::Char(c))), Quit::No);
        }
    }

    fn screen(app: &mut App) -> Vec<String> {
        let area = Rect::new(0, 0, 120, 36);
        let mut buf = Buffer::empty(area);
        app.render(area, &mut buf);
        (0..36).map(|y| (0..120).map(|x| buf[(x, y)].symbol().to_string()).collect::<String>().trim_end().to_string()).collect()
    }

    fn head(d: &Path) -> String {
        Repo::discover(d).unwrap().branch().unwrap()
    }

    #[test]
    fn shows_the_four_panes_and_the_log() {
        let d = repo("panes");
        let mut app = App::new(&d).unwrap();
        let all = screen(&mut app).join("\n");
        for title in ["Files", "Branches", "Commits", "Stashes"] {
            assert!(all.contains(title), "{title} in\n{all}");
        }
        assert!(all.contains("first commit") && all.contains("main") && all.contains("other"), "{all}");
    }

    #[test]
    fn focus_moves_with_tab_and_digits_and_q_quits() {
        let d = repo("focus");
        let mut app = App::new(&d).unwrap();
        press(&mut app, "3");
        assert_eq!(app.focus, Focus::Commits);
        app.handle_event(&key(KeyCode::Tab));
        assert_eq!(app.focus, Focus::Stashes);
        app.handle_event(&key(KeyCode::Tab));
        assert_eq!(app.focus, Focus::Files);
        app.handle_event(&Event::Key(KeyEvent::new(KeyCode::BackTab, KeyModifiers::SHIFT)));
        assert_eq!(app.focus, Focus::Stashes);
        assert_eq!(app.handle_event(&key(KeyCode::Char('q'))), Quit::Yes);
    }

    #[test]
    fn branches_checkout_create_and_delete() {
        let d = repo("branches");
        let mut app = App::new(&d).unwrap();
        press(&mut app, "2");
        // main (checked out) is first, `other` second: j then Enter switches.
        press(&mut app, "j");
        app.handle_event(&key(KeyCode::Enter));
        assert_eq!(head(&d), "other");
        // New branch through the prompt.
        press(&mut app, "n");
        press(&mut app, "topic");
        app.handle_event(&key(KeyCode::Enter));
        assert_eq!(head(&d), "topic");
        // Delete `other` (not checked out) with a confirmation.
        let other = app.branches.iter().position(|b| b.name == "other").unwrap();
        app.lists[0].cursor = other;
        press(&mut app, "d");
        assert!(matches!(app.mode, Mode::Confirm(_)));
        press(&mut app, "y");
        assert!(app.branches.iter().all(|b| b.name != "other"), "{:?}", app.branches);
        // The checked-out branch cannot be deleted.
        app.lists[0].cursor = app.branches.iter().position(|b| b.is_head).unwrap();
        press(&mut app, "d");
        assert!(matches!(app.mode, Mode::Normal) && app.message.as_ref().is_some_and(|(_, e)| *e));
    }

    #[test]
    fn stash_new_apply_pop_and_drop() {
        let d = repo("stash");
        let mut app = App::new(&d).unwrap();
        fs::write(d.join("a.txt"), "changed\n").unwrap();
        press(&mut app, "4");
        press(&mut app, "n");
        press(&mut app, "wip");
        app.handle_event(&key(KeyCode::Enter));
        assert_eq!(app.stashes.len(), 1, "{:?}", app.message);
        assert_eq!(fs::read_to_string(d.join("a.txt")).unwrap(), "1\n2\n");
        press(&mut app, "p");
        assert!(app.stashes.is_empty());
        assert_eq!(fs::read_to_string(d.join("a.txt")).unwrap(), "changed\n");
        // Drop asks first.
        press(&mut app, "n");
        press(&mut app, "again");
        app.handle_event(&key(KeyCode::Enter));
        assert_eq!(app.stashes.len(), 1);
        press(&mut app, "d");
        press(&mut app, "n"); // anything but y cancels
        assert_eq!(app.stashes.len(), 1);
        press(&mut app, "d");
        press(&mut app, "y");
        assert!(app.stashes.is_empty());
    }

    #[test]
    fn initials_and_author_colors() {
        assert_eq!(initials("Chetan Singh Sajwan"), "CS");
        assert_eq!(initials("root"), "ro");
        assert_eq!(initials("Ada"), "Ad");
        assert_eq!(initials("  "), "?");
        let t = Theme::default();
        assert_eq!(author_color(&t, "Ada Lovelace"), author_color(&t, "Ada Lovelace"));
    }

    #[test]
    fn the_files_pane_still_stages_and_commits() {
        let d = repo("files");
        let mut app = App::new(&d).unwrap();
        fs::write(d.join("a.txt"), "1\n2\n3\n").unwrap();
        app.reload_all();
        press(&mut app, "s"); // stage the highlighted file
        press(&mut app, "c");
        press(&mut app, "second");
        app.handle_event(&key(KeyCode::Enter));
        assert_eq!(app.commits.len(), 2, "{:?}", app.message);
        assert_eq!(app.commits[0].subject, "second");
    }
}
