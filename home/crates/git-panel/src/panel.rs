use git_core::{Kind, Repo, Side};
use ratatui::buffer::Buffer;
use ratatui::crossterm::event::{Event, KeyCode, KeyEvent, KeyEventKind, KeyModifiers};
use ratatui::layout::Rect;
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Paragraph, Widget};
use std::path::{Path, PathBuf};
use tui_input::backend::crossterm::EventHandler;
use tui_input::Input;
use ui::{Pane, Theme, layout};

/// What the host should do after an event.
#[derive(Debug, PartialEq, Eq)]
pub enum Action {
    None,
    /// The user chose a file to open (absolute path).
    Open(PathBuf),
    /// Leave the panel (Esc, `q`).
    Close,
    /// The repository changed (stage, unstage, discard, commit): hosts may want
    /// to refresh their own views.
    Changed,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Section {
    Conflicts,
    Staged,
    Unstaged,
    Untracked,
}

impl Section {
    fn title(self) -> &'static str {
        match self {
            Section::Conflicts => "Conflicts",
            Section::Staged => "Staged",
            Section::Unstaged => "Unstaged",
            Section::Untracked => "Untracked",
        }
    }
}

enum Row {
    Header(Section, usize),
    File { section: Section, rela: PathBuf, kind: Kind },
}

enum Mode {
    Normal,
    /// Commit message prompt.
    Commit(Input),
    /// Discard confirmation for this file.
    Discard(PathBuf, bool),
}

struct Preview {
    key: (PathBuf, bool, u16, u16, u64),
    lines: Vec<Line<'static>>,
}

pub struct Panel {
    repo: Repo,
    root: PathBuf,
    rows: Vec<Row>,
    /// Indices into `rows` of the selectable (file) rows.
    items: Vec<usize>,
    /// Position in `items`.
    cursor: usize,
    offset: usize,
    page: usize,
    branch: String,
    mode: Mode,
    message: Option<(String, bool)>,
    preview: Option<Preview>,
    /// Bumped when the repository changes, so cached diffs are dropped.
    version: u64,
    pscroll: usize,
    pheight: usize,
    /// Title of the list pane instead of `git: <branch>`.
    title: Option<String>,
}

fn kind_char(k: Kind) -> char {
    match k {
        Kind::Added => 'A',
        Kind::Modified => 'M',
        Kind::Deleted => 'D',
        Kind::Renamed => 'R',
        Kind::Typechange => 'T',
        Kind::Untracked => '?',
        Kind::Conflict => 'U',
    }
}

impl Panel {
    /// The panel for the repository containing `path`; `None` if there is none.
    pub fn new(path: &Path) -> Option<Panel> {
        let repo = Repo::discover(path)?;
        let root = repo.root().to_path_buf();
        let mut p = Panel {
            repo,
            root,
            rows: Vec::new(),
            items: Vec::new(),
            cursor: 0,
            offset: 0,
            page: 10,
            branch: String::new(),
            mode: Mode::Normal,
            message: None,
            preview: None,
            version: 0,
            pscroll: 0,
            pheight: 10,
            title: None,
        };
        p.refresh();
        Some(p)
    }

    pub fn root(&self) -> &Path {
        &self.root
    }

    /// Reread the status, keeping the cursor on the same file where possible.
    pub fn refresh(&mut self) {
        let keep = self.current().map(|(s, p, _)| (s, p.to_path_buf()));
        self.branch = self.repo.branch().unwrap_or_else(|| "(detached)".into());
        let status = self.repo.status().unwrap_or_default();
        let mut buckets: [Vec<(PathBuf, Kind)>; 4] = Default::default();
        for (path, st) in status.iter() {
            let p = path.to_path_buf();
            if st.unstaged == Some(Kind::Conflict) {
                buckets[0].push((p.clone(), Kind::Conflict));
                continue;
            }
            if let Some(k) = st.staged {
                buckets[1].push((p.clone(), k));
            }
            match st.unstaged {
                Some(Kind::Untracked) => buckets[3].push((p, Kind::Untracked)),
                Some(k) => buckets[2].push((p, k)),
                None => {}
            }
        }
        self.rows.clear();
        self.items.clear();
        for (i, section) in [Section::Conflicts, Section::Staged, Section::Unstaged, Section::Untracked].into_iter().enumerate() {
            let mut files = std::mem::take(&mut buckets[i]);
            if files.is_empty() {
                continue;
            }
            files.sort_by(|a, b| a.0.cmp(&b.0));
            self.rows.push(Row::Header(section, files.len()));
            for (rela, kind) in files {
                self.items.push(self.rows.len());
                self.rows.push(Row::File { section, rela, kind });
            }
        }
        // Stay on the same file: in the same section if it is still there, else
        // wherever it moved to (staging moves a file from Unstaged to Staged).
        let find = |panel: &Panel, same_section: Option<Section>, p: &Path| {
            panel.items.iter().position(|&i| matches!(&panel.rows[i], Row::File { section, rela, .. } if rela == p && same_section.is_none_or(|s| s == *section)))
        };
        self.cursor = keep
            .and_then(|(s, p)| find(self, Some(s), &p).or_else(|| find(self, None, &p)))
            .unwrap_or(self.cursor)
            .min(self.items.len().saturating_sub(1));
        self.version += 1;
        self.pscroll = 0;
    }

    /// Section, path and kind of the highlighted file.
    fn current(&self) -> Option<(Section, &Path, Kind)> {
        match self.rows.get(*self.items.get(self.cursor)?)? {
            Row::File { section, rela, kind } => Some((*section, rela.as_path(), *kind)),
            Row::Header(..) => None,
        }
    }

    fn say(&mut self, msg: impl Into<String>, error: bool) {
        self.message = Some((msg.into(), error));
    }

    fn move_by(&mut self, delta: isize) {
        let last = self.items.len().saturating_sub(1) as isize;
        self.cursor = (self.cursor as isize + delta).clamp(0, last.max(0)) as usize;
    }

    fn run(&mut self, what: &str, result: Result<(), git_core::Error>) -> Action {
        match result {
            Ok(()) => {
                self.say(what, false);
                self.refresh();
                Action::Changed
            }
            Err(e) => {
                self.say(e.to_string(), true);
                Action::None
            }
        }
    }

    /// Whether the commit message is being typed (so keys like space are text, not commands).
    pub fn is_typing(&self) -> bool {
        matches!(self.mode, Mode::Commit(..))
    }

    pub fn handle_event(&mut self, ev: &Event) -> Action {
        let Event::Key(key @ KeyEvent { kind, .. }) = ev else { return Action::None };
        if *kind == KeyEventKind::Release {
            return Action::None;
        }
        match std::mem::replace(&mut self.mode, Mode::Normal) {
            Mode::Commit(input) => return self.commit_key(input, ev, key),
            Mode::Discard(rela, untracked) => {
                return match key.code {
                    KeyCode::Char('y' | 'Y') | KeyCode::Enter => {
                        let r = self.repo.discard(&rela, untracked);
                        self.run(if untracked { "deleted" } else { "discarded" }, r)
                    }
                    _ => Action::None,
                };
            }
            Mode::Normal => {}
        }
        self.message = None;
        let ctrl = key.modifiers.contains(KeyModifiers::CONTROL);
        match key.code {
            KeyCode::Esc | KeyCode::Char('q') => return Action::Close,
            KeyCode::Char('c') if ctrl => return Action::Close,
            KeyCode::Up | KeyCode::Char('k') => self.move_by(-1),
            KeyCode::Down | KeyCode::Char('j') => self.move_by(1),
            KeyCode::Char('p') if ctrl => self.move_by(-1),
            KeyCode::Char('n') if ctrl => self.move_by(1),
            KeyCode::PageUp => self.move_by(-(self.page as isize)),
            KeyCode::PageDown => self.move_by(self.page as isize),
            KeyCode::Home | KeyCode::Char('g') => self.cursor = 0,
            KeyCode::End | KeyCode::Char('G') => self.cursor = self.items.len().saturating_sub(1),
            KeyCode::Char('d') if ctrl => self.pscroll += (self.pheight / 2).max(1),
            KeyCode::Char('u') if ctrl => self.pscroll = self.pscroll.saturating_sub((self.pheight / 2).max(1)),
            KeyCode::Enter => {
                if let Some((_, rela, _)) = self.current() {
                    return Action::Open(self.root.join(rela));
                }
            }
            KeyCode::Char(' ') => {
                if let Some((section, rela, _)) = self.current() {
                    let rela = rela.to_path_buf();
                    return if section == Section::Staged { self.unstage(rela) } else { self.stage(rela) };
                }
            }
            KeyCode::Char('s') => {
                if let Some((section, rela, _)) = self.current() {
                    if section != Section::Staged {
                        let rela = rela.to_path_buf();
                        return self.stage(rela);
                    }
                }
            }
            KeyCode::Char('u') => {
                if let Some((Section::Staged, rela, _)) = self.current() {
                    let rela = rela.to_path_buf();
                    return self.unstage(rela);
                }
            }
            KeyCode::Char('a') => {
                let r = self.repo.stage_all();
                return self.run("staged everything", r);
            }
            KeyCode::Char('A') => {
                let r = self.repo.unstage_all();
                return self.run("unstaged everything", r);
            }
            KeyCode::Char('x') => {
                // Discard: only work-tree changes, never the staged ones.
                if let Some((section, rela, _)) = self.current() {
                    match section {
                        Section::Unstaged | Section::Untracked => self.mode = Mode::Discard(rela.to_path_buf(), section == Section::Untracked),
                        _ => self.say("nothing to discard here (unstage it first)", true),
                    }
                }
            }
            KeyCode::Char('c') => {
                if self.rows.iter().any(|r| matches!(r, Row::File { section: Section::Staged, .. })) {
                    self.mode = Mode::Commit(Input::default());
                } else {
                    self.say("nothing staged to commit (stage with s or Space)", true);
                }
            }
            KeyCode::Char('r') => {
                self.refresh();
                self.say("refreshed", false);
            }
            _ => {}
        }
        Action::None
    }

    fn stage(&mut self, rela: PathBuf) -> Action {
        let r = self.repo.stage(std::slice::from_ref(&rela));
        self.run("staged", r)
    }

    fn unstage(&mut self, rela: PathBuf) -> Action {
        let r = self.repo.unstage(std::slice::from_ref(&rela));
        self.run("unstaged", r)
    }

    fn commit_key(&mut self, mut input: Input, ev: &Event, key: &KeyEvent) -> Action {
        match key.code {
            KeyCode::Esc => Action::None,
            KeyCode::Enter => {
                let message = input.value().to_string();
                match self.repo.create_commit(&message) {
                    Ok(summary) => {
                        self.say(format!("committed {summary}"), false);
                        self.refresh();
                        Action::Changed
                    }
                    Err(e) => {
                        self.say(e.to_string(), true);
                        // Keep what was typed so the message is not lost.
                        self.mode = Mode::Commit(input);
                        Action::None
                    }
                }
            }
            _ => {
                input.handle_event(ev);
                self.mode = Mode::Commit(input);
                Action::None
            }
        }
    }

    fn kind_color(theme: &Theme, kind: Kind) -> Color {
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

    /// The footer rows: the commit prompt, a discard question, or the last
    /// message. While the commit prompt is open an error (a refused commit) is
    /// shown above it, so it is not hidden by what you are typing.
    fn footer(&self, theme: &Theme) -> Vec<Line<'static>> {
        let c = &theme.colors;
        let message = self.message.as_ref().map(|(m, err)| Line::from(Span::styled(m.clone(), Style::new().fg(if *err { c.error } else { c.muted }.into()))));
        match &self.mode {
            Mode::Commit(input) => {
                let prompt = Line::from(vec![
                    Span::styled("commit: ", Style::new().fg(c.accent.into())),
                    Span::styled(input.value().to_string(), Style::new().fg(c.fg.into())),
                ]);
                message.into_iter().chain(std::iter::once(prompt)).collect()
            }
            Mode::Discard(rela, untracked) => {
                let what = if *untracked { "Delete untracked" } else { "Discard changes to" };
                vec![Line::from(Span::styled(format!("{what} {}? (y/n)", rela.display()), Style::new().fg(c.warning.into())))]
            }
            Mode::Normal => message.into_iter().collect(),
        }
    }

    /// Only the file list (no diff pane), for a narrow dock; `focused` colors
    /// the border like any focused pane.
    pub fn render_compact(&mut self, area: Rect, buf: &mut Buffer, theme: &Theme, focused: bool) {
        self.render_list(area, buf, theme, focused);
    }

    /// Only the diff of the highlighted file, for a host that lays the panes out itself.
    pub fn render_preview_pane(&mut self, area: Rect, buf: &mut Buffer, theme: &Theme) {
        self.render_preview(area, buf, theme);
    }

    /// Replace the list pane's title (`git: <branch>` by default).
    pub fn set_title(&mut self, title: impl Into<String>) {
        self.title = Some(title.into());
    }

    /// The checked-out branch, as of the last refresh.
    pub fn branch(&self) -> &str {
        &self.branch
    }

    pub fn render(&mut self, area: Rect, buf: &mut Buffer, theme: &Theme) {
        let [list_area, preview_area] = layout::main_preview(theme, area);
        self.render_list(list_area, buf, theme, true);
        self.render_preview(preview_area, buf, theme);
    }

    fn render_list(&mut self, area: Rect, buf: &mut Buffer, theme: &Theme, focused: bool) {
        let c = &theme.colors;
        let title = self.title.clone().unwrap_or_else(|| format!("git: {}", self.branch));
        let pane = Pane::new(theme).title(&title).icon(ui::icons::GIT).focused(focused);
        let mut inner = pane.inner(area);
        pane.render(area, buf);
        if inner.height == 0 || inner.width < 6 {
            return;
        }
        let footer = self.footer(theme);
        if !footer.is_empty() {
            let rows = (footer.len() as u16).min(inner.height);
            let top = inner.bottom() - rows;
            for (i, line) in footer.into_iter().rev().take(usize::from(rows)).collect::<Vec<_>>().into_iter().rev().enumerate() {
                Paragraph::new(line).render(Rect { y: top + i as u16, height: 1, ..inner }, buf);
            }
            if let Mode::Commit(input) = &self.mode {
                // The prompt is the last footer row.
                let (x, y) = (inner.x + 8 + input.visual_cursor() as u16, inner.bottom() - 1);
                if x < inner.right() {
                    if let Some(cell) = buf.cell_mut((x, y)) {
                        cell.set_style(Style::new().add_modifier(Modifier::REVERSED));
                    }
                }
            }
            inner.height -= rows;
            if inner.height == 0 {
                return;
            }
        }
        if self.rows.is_empty() {
            buf.set_string(inner.x + 1, inner.y, "clean: nothing to commit", Style::new().fg(c.muted.into()));
            return;
        }

        self.page = usize::from(inner.height).max(1);
        let crow = self.items.get(self.cursor).copied().unwrap_or(0);
        if crow < self.offset {
            self.offset = crow;
        } else if crow >= self.offset + self.page {
            self.offset = crow + 1 - self.page;
        }
        let geo = ui::list::Rows::new(area, inner);
        for (i, row) in self.rows.iter().enumerate().skip(self.offset).take(self.page) {
            let y = inner.y + (i - self.offset) as u16;
            let area = Rect { y, height: 1, ..inner };
            match row {
                Row::Header(section, n) => {
                    let color = match section {
                        Section::Conflicts => c.git.conflict,
                        Section::Staged => c.git.added,
                        Section::Unstaged => c.git.modified,
                        Section::Untracked => c.git.untracked,
                    };
                    let line = Line::from(vec![
                        Span::styled("▾ ", Style::new().fg(c.muted.into())),
                        Span::styled(format!("{} ({n})", section.title()), Style::new().fg(color.into()).add_modifier(Modifier::BOLD)),
                    ]);
                    Paragraph::new(line).render(area, buf);
                }
                Row::File { rela, kind, .. } => {
                    let selected = i == crow;
                    let color = Self::kind_color(theme, *kind);
                    let base = ui::list::style(theme, selected, Some(color));
                    buf.set_style(geo.bar(y), base);
                    let line = Line::from(vec![
                                                Span::styled(format!("{} ", kind_char(*kind)), Style::new().fg(color)),
                        Span::styled(rela.display().to_string(), Style::new().fg(c.fg.into())),
                    ]);
                    Paragraph::new(line).style(base).render(area, buf);
                }
            }
        }
    }

    fn render_preview(&mut self, area: Rect, buf: &mut Buffer, theme: &Theme) {
        let current = self.current().map(|(s, p, _)| (s, p.to_path_buf()));
        let title = current.as_ref().map(|(_, p)| p.display().to_string()).unwrap_or_default();
        let name = title.trim_end_matches('/').rsplit('/').next().unwrap_or(&title).to_string();
        let pane = Pane::new(theme).title(&title).icon(ui::icons::file(&name, false));
        let inner = pane.inner(area);
        pane.render(area, buf);
        let Some((section, rela)) = current else {
            self.preview = None;
            return;
        };
        if inner.width == 0 || inner.height == 0 {
            return;
        }
        let staged = section == Section::Staged;
        let key = (rela.clone(), staged, inner.width, inner.height, self.version);
        if self.preview.as_ref().map(|p| &p.key) != Some(&key) {
            let opts = pv::Options { width: Some(inner.width), height: None, git: false, focus: None };
            let side = if staged { Side::Staged } else { Side::Unstaged };
            let lines = match pv::preview_diff(&self.root, &rela, side, theme, &opts) {
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
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::process::Command;

    /// Commits made through `Repo::create_commit` use the ambient git identity,
    /// which a clean build sandbox does not have.
    fn identity() {
        static ONCE: std::sync::Once = std::sync::Once::new();
        ONCE.call_once(|| {
            for (k, v) in [("GIT_AUTHOR_NAME", "t"), ("GIT_AUTHOR_EMAIL", "t@t"), ("GIT_COMMITTER_NAME", "t"), ("GIT_COMMITTER_EMAIL", "t@t")] {
                // SAFETY: set once, before any test spawns git, to constants.
                unsafe { std::env::set_var(k, v) };
            }
        });
    }

    fn git(dir: &Path, args: &[&str]) {
        assert!(Command::new("git")
            .args(["-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false"])
            .args(args)
            .current_dir(dir)
            .env("GIT_CONFIG_GLOBAL", "/dev/null")
            .env("GIT_CONFIG_SYSTEM", "/dev/null")
            .status()
            .unwrap()
            .success());
    }

    /// A repo with: a.txt modified (unstaged), b.txt modified and staged, new.txt untracked.
    fn repo(name: &str) -> PathBuf {
        identity();
        let d = std::env::temp_dir().join(format!("git-panel-test-{}-{name}", std::process::id()));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(&d).unwrap();
        git(&d, &["init", "-q", "-b", "main"]);
        fs::write(d.join("a.txt"), "a1\na2\n").unwrap();
        fs::write(d.join("b.txt"), "b1\nb2\n").unwrap();
        git(&d, &["add", "."]);
        git(&d, &["commit", "-q", "-m", "init"]);
        fs::write(d.join("a.txt"), "a1\nA2 changed\n").unwrap();
        fs::write(d.join("b.txt"), "b1\nB2 staged\n").unwrap();
        git(&d, &["add", "b.txt"]);
        fs::write(d.join("new.txt"), "brand new\n").unwrap();
        d.canonicalize().unwrap()
    }

    fn key(c: KeyCode) -> Event {
        Event::Key(KeyEvent::new(c, KeyModifiers::NONE))
    }

    fn press(p: &mut Panel, s: &str) -> Action {
        let mut last = Action::None;
        for c in s.chars() {
            last = p.handle_event(&key(KeyCode::Char(c)));
        }
        last
    }

    fn draw(p: &mut Panel) -> Vec<String> {
        let area = Rect::new(0, 0, 100, 16);
        let mut b = Buffer::empty(area);
        p.render(area, &mut b, &Theme::default());
        (0..16).map(|y| (0..100).map(|x| b[(x, y)].symbol().to_string()).collect::<String>()).collect()
    }

    fn on(p: &mut Panel, name: &str) {
        let i = p.items.iter().position(|&i| matches!(&p.rows[i], Row::File { rela, .. } if rela == Path::new(name))).unwrap_or_else(|| panic!("{name} listed"));
        p.cursor = i;
    }

    #[test]
    fn lists_the_sections_in_order_with_counts_and_the_branch() {
        let mut p = Panel::new(&repo("sections")).unwrap();
        let text = draw(&mut p).join("\n");
        let pos = |s: &str| text.find(s).unwrap_or_else(|| panic!("{s} in\n{text}"));
        assert!(pos("main") < pos("Staged (1)") && pos("Staged (1)") < pos("Unstaged (1)") && pos("Unstaged (1)") < pos("Untracked (1)"));
        assert!(pos("M b.txt") < pos("M a.txt") && pos("M a.txt") < pos("? new.txt"), "{text}");
    }

    #[test]
    fn space_stages_and_unstages_and_the_cursor_stays_on_the_file() {
        let d = repo("toggle");
        let mut p = Panel::new(&d).unwrap();
        on(&mut p, "new.txt");
        assert_eq!(press(&mut p, " "), Action::Changed);
        assert_eq!(p.current().map(|(s, f, _)| (s, f.to_path_buf())), Some((Section::Staged, PathBuf::from("new.txt"))));
        assert!(p.repo.status().unwrap().get(Path::new("new.txt")).unwrap().staged == Some(Kind::Added));
        assert_eq!(press(&mut p, " "), Action::Changed); // toggles back
        assert_eq!(p.current().map(|(s, ..)| s), Some(Section::Untracked));
        // `s` only stages, `u` only unstages.
        on(&mut p, "a.txt");
        assert_eq!(press(&mut p, "u"), Action::None);
        assert_eq!(press(&mut p, "s"), Action::Changed);
        assert_eq!(press(&mut p, "A"), Action::Changed);
        assert!(p.items.iter().all(|&i| !matches!(&p.rows[i], Row::File { section: Section::Staged, .. })));
        assert_eq!(press(&mut p, "a"), Action::Changed);
        assert!(p.items.iter().all(|&i| matches!(&p.rows[i], Row::File { section: Section::Staged, .. })));
    }

    #[test]
    fn x_asks_before_discarding_and_never_touches_staged_changes() {
        let d = repo("discard");
        let mut p = Panel::new(&d).unwrap();
        on(&mut p, "b.txt"); // staged
        press(&mut p, "x");
        assert!(matches!(p.mode, Mode::Normal), "staged files are not discarded");
        assert!(p.message.as_ref().is_some_and(|(_, err)| *err));

        on(&mut p, "a.txt");
        press(&mut p, "x");
        assert!(draw(&mut p).join("\n").contains("Discard changes to a.txt? (y/n)"));
        assert_eq!(press(&mut p, "n"), Action::None);
        assert_eq!(fs::read_to_string(d.join("a.txt")).unwrap(), "a1\nA2 changed\n");
        press(&mut p, "x");
        assert_eq!(press(&mut p, "y"), Action::Changed);
        assert_eq!(fs::read_to_string(d.join("a.txt")).unwrap(), "a1\na2\n");

        on(&mut p, "new.txt");
        press(&mut p, "x");
        assert!(draw(&mut p).join("\n").contains("Delete untracked new.txt? (y/n)"));
        assert_eq!(press(&mut p, "y"), Action::Changed);
        assert!(!d.join("new.txt").exists());
    }

    #[test]
    fn c_commits_the_staged_files_with_the_typed_message() {
        let d = repo("commit");
        let mut p = Panel::new(&d).unwrap();
        // Empty message: refused, the prompt stays so nothing typed is lost.
        press(&mut p, "c");
        assert!(draw(&mut p).join("\n").contains("commit: "));
        assert_eq!(p.handle_event(&key(KeyCode::Enter)), Action::None);
        assert!(matches!(p.mode, Mode::Commit(_)) && p.message.as_ref().is_some_and(|(_, e)| *e));
        let shown = draw(&mut p).join("\n");
        assert!(shown.contains("empty commit message") && shown.contains("commit: "), "the refusal is visible above the prompt:\n{shown}");
        press(&mut p, "fix b");
        assert!(draw(&mut p).join("\n").contains("commit: fix b"));
        assert_eq!(p.handle_event(&key(KeyCode::Enter)), Action::Changed);
        let log = p.repo.commits(2).unwrap();
        assert_eq!(log[0].subject, "fix b");
        // The staged section is gone; the unstaged and untracked files remain.
        let text = draw(&mut p).join("\n");
        assert!(!text.contains("Staged (") && text.contains("Unstaged (1)") && text.contains("committed "), "{text}");
        // Esc cancels the prompt.
        press(&mut p, "c"); // nothing staged now
        assert!(p.message.as_ref().is_some_and(|(m, e)| *e && m.contains("nothing staged")));
    }

    #[test]
    fn enter_opens_the_file_and_the_preview_shows_the_right_side_of_the_diff() {
        let d = repo("preview");
        let mut p = Panel::new(&d).unwrap();
        on(&mut p, "a.txt");
        let text = draw(&mut p).join("\n");
        assert!(text.contains("A2 changed") && !text.contains("B2 staged"), "unstaged diff of a.txt:\n{text}");
        on(&mut p, "b.txt");
        let text = draw(&mut p).join("\n");
        assert!(text.contains("B2 staged"), "staged diff of b.txt:\n{text}");
        assert_eq!(p.handle_event(&key(KeyCode::Enter)), Action::Open(d.join("b.txt")));
        assert_eq!(p.handle_event(&key(KeyCode::Esc)), Action::Close);
    }

    #[test]
    fn a_clean_repo_and_a_non_repo() {
        let d = std::env::temp_dir().join(format!("git-panel-test-{}-clean", std::process::id()));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(&d).unwrap();
        assert!(Panel::new(&d).is_none());
        git(&d, &["init", "-q", "-b", "main"]);
        let mut p = Panel::new(&d).unwrap();
        assert!(draw(&mut p).join("\n").contains("clean: nothing to commit"));
        assert_eq!(press(&mut p, "j"), Action::None); // navigation on an empty list is harmless
    }
}
