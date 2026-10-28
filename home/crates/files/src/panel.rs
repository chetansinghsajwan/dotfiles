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
}

struct Row {
    path: PathBuf,
    name: String,
    depth: u16,
    is_dir: bool,
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
}

impl Panel {
    pub fn new(root: impl Into<PathBuf>, opts: PanelOptions) -> Self {
        let root = root.into();
        let root = root.canonicalize().unwrap_or(root);
        let mut p = Panel { root, opts, expanded: BTreeSet::new(), rows: Vec::new(), cursor: 0, offset: 0, page: 10, git: None };
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

    pub fn handle_event(&mut self, ev: &Event) -> Action {
        let Event::Key(KeyEvent { code, modifiers, kind, .. }) = ev else { return Action::None };
        if *kind == KeyEventKind::Release {
            return Action::None;
        }
        let ctrl = modifiers.contains(KeyModifiers::CONTROL);
        match code {
            KeyCode::Esc | KeyCode::Char('q') => return Action::Close,
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
            KeyCode::Char('r') => self.refresh(),
            _ => {}
        }
        Action::None
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

    /// Draw the panel in `area`; `focused` colors the border like any focused pane.
    pub fn render(&mut self, area: Rect, buf: &mut Buffer, theme: &Theme, focused: bool) {
        let c = &theme.colors;
        let title = self.root.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_else(|| "/".into());
        let pane = Pane::new(theme).title(&title).focused(focused);
        let inner = pane.inner(area);
        pane.render(area, buf);
        if inner.height == 0 || inner.width < 4 {
            return;
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
            let base = if selected && focused { Style::new().bg(c.selection.into()) } else { Style::new() };
            buf.set_style(area, base);

            let git = self.git_state(row);
            let color = git.map(|(_, k)| Self::git_color(theme, k)).unwrap_or(if row.is_dir { c.accent.into() } else { c.fg.into() });
            let arrow = if !row.is_dir {
                "  "
            } else if self.expanded.contains(&row.path) {
                "▾ "
            } else {
                "▸ "
            };
            let mut name_style = Style::new().fg(color);
            if row.is_dir {
                name_style = name_style.add_modifier(Modifier::BOLD);
            }
            let line = Line::from(vec![
                Span::raw(" ".repeat(usize::from(row.depth) * 2)),
                Span::styled(arrow, Style::new().fg(c.muted.into())),
                Span::styled(if row.is_dir { format!("{}/", row.name) } else { row.name.clone() }, name_style),
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
        assert!(text.iter().any(|l| l.contains("src/") && l.trim_end().trim_end_matches('│').trim_end().ends_with('•')), "{text:?}");
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
        assert!(all.contains("files-test-") && all.contains("docs/"), "{all}");
        p.handle_event(&key(KeyCode::Char('G')));
        let mut buf = Buffer::empty(area);
        p.render(area, &mut buf, &Theme::default(), true);
        let all: String = (0..8).map(|y| (0..30).map(|x| buf[(x, y)].symbol().to_string()).collect::<String>() + "\n").collect();
        assert!(all.contains("file29.txt") && !all.contains("docs/"), "{all}");
    }
}
