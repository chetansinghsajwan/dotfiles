use crate::candidate::Candidate;
use crate::grep;
use git_core::{Repo, Status};
use nucleo::pattern::{CaseMatching, Normalization};
use nucleo::{Config, Injector, Matcher, Nucleo};
use ratatui::buffer::Buffer;
use ratatui::crossterm::event::{Event, KeyCode, KeyEvent, KeyEventKind, KeyModifiers};
use ratatui::layout::Rect;
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Paragraph, Widget};
use std::collections::BTreeSet;
use std::path::PathBuf;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use tui_input::Input;
use tui_input::backend::crossterm::EventHandler;
use ui::{Pane, Theme, layout};

/// How the query is used.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Mode {
    /// Fuzzy-filter the candidates pushed through `injector()`.
    Fuzzy,
    /// The query is a regex searched for in the files under `root`; matches are
    /// the candidates.
    Grep,
}

#[derive(Debug, Clone)]
pub struct PickerOptions {
    pub mode: Mode,
    /// Candidates are paths relative to `root`: path-aware scoring, preview and git state.
    /// Always true in `Mode::Grep`.
    pub paths: bool,
    pub root: PathBuf,
    pub preview: bool,
    pub git: bool,
    pub query: String,
}

/// What the host should do after an event.
#[derive(Debug, PartialEq, Eq)]
pub enum Action {
    None,
    /// The user accepted: the marked candidates, or the highlighted one
    /// (`Candidate::output` form).
    Accept(Vec<String>),
    /// One of the `--expect` keys was pressed: its name and the selection
    /// (like `Accept`). The host runs the action tied to the key.
    AcceptWith(String, Vec<String>),
    Cancel,
}

struct Preview {
    key: (String, u32, u16, u16),
    lines: Vec<Line<'static>>,
}

pub struct Picker {
    opts: PickerOptions,
    nucleo: Nucleo<Candidate>,
    matcher: Matcher,
    input: Input,
    last_query: String,
    /// Index into the matched list.
    cursor: u32,
    offset: u32,
    marked: BTreeSet<String>,
    git: Option<(Repo, Status)>,
    preview: Option<Preview>,
    /// Rows visible in the list at the last render, for paging.
    page: u32,
    /// Stops the running grep search.
    cancel: Arc<AtomicBool>,
    /// First visible preview row (commit previews scroll).
    pscroll: usize,
    /// Pane title override (`--title`).
    title: Option<String>,
    /// External preview command for candidates that are plain text (`--preview-cmd`).
    preview_cmd: Option<crate::preview_cmd::PreviewCmd>,
    /// Keys that accept and report themselves (`--expect`).
    expect: Vec<(String, KeyEvent)>,
    /// Fixed lines under the prompt (`--header-lines`).
    header: Vec<String>,
    /// Preview rows visible at the last render, for paging.
    pheight: usize,
}

impl Picker {
    /// `notify` is called from worker threads when results changed; the host
    /// should wake its event loop and call `tick`.
    pub fn new(mut opts: PickerOptions, notify: Arc<dyn Fn() + Send + Sync>) -> Self {
        if opts.mode == Mode::Grep {
            opts.paths = true;
        }
        let config = if opts.paths { Config::DEFAULT.match_paths() } else { Config::DEFAULT };
        let git = if opts.git && opts.paths {
            Repo::discover(&opts.root).and_then(|r| r.status().ok().map(|s| (r, s)))
        } else {
            None
        };
        let mut picker = Picker {
            nucleo: Nucleo::new(config, notify, None, 1),
            matcher: Matcher::new(Config::DEFAULT),
            input: Input::new(opts.query.clone()),
            last_query: String::new(),
            cursor: 0,
            offset: 0,
            marked: BTreeSet::new(),
            git,
            preview: None,
            page: 10,
            cancel: Arc::new(AtomicBool::new(false)),
            pscroll: 0,
            title: None,
            preview_cmd: None,
            expect: Vec::new(),
            header: Vec::new(),
            pheight: 10,
            opts,
        };
        picker.reparse();
        picker
    }

    /// Where candidates are pushed in `Mode::Fuzzy`. (Grep mode feeds itself.)
    pub fn injector(&self) -> Injector<Candidate> {
        self.nucleo.injector()
    }

    /// Keys (`ctrl-e`, `alt-x`, `f2`, ...) that accept and report themselves
    /// through `Action::AcceptWith`. Fails on a name that is not understood.
    pub fn set_expect(&mut self, keys: &[String]) -> Result<(), String> {
        let mut out = Vec::new();
        for k in keys {
            let ev = crate::keys::parse(k).ok_or_else(|| format!("unknown key: {k}"))?;
            out.push((k.clone(), ev));
        }
        self.expect = out;
        Ok(())
    }

    /// Fixed lines shown under the prompt, e.g. a table's column names.
    pub fn set_header(&mut self, lines: Vec<String>) {
        self.header = lines;
    }

    /// Title of the list pane instead of `pick` / `grep`.
    pub fn set_title(&mut self, title: impl Into<String>) {
        self.title = Some(title.into());
    }

    /// Preview plain-text candidates with `cmd` (run through `sh -c`; `{}`, `{N}`
    /// and `{N..}` are replaced by the highlighted line or its fields, split on
    /// `delimiter` or whitespace). Turns the preview pane on.
    pub fn set_preview_command(&mut self, cmd: impl Into<String>, delimiter: Option<String>) {
        self.preview_cmd = Some(crate::preview_cmd::PreviewCmd { cmd: cmd.into(), delimiter });
        self.opts.preview = true;
    }

    /// Put the cursor on the `index`-th result (0-based), e.g. to preselect the
    /// previous buffer. Takes effect once the candidates are in (see `tick`).
    pub fn set_cursor(&mut self, index: u32) {
        // Let the matcher finish the candidates pushed so far (a few ms at most).
        for _ in 0..40 {
            if !self.nucleo.tick(5).running {
                break;
            }
        }
        self.cursor = index;
        self.clamp();
    }

    /// Advance the matcher. Returns true if the result list changed (redraw).
    pub fn tick(&mut self) -> bool {
        let changed = self.nucleo.tick(10).changed;
        if changed {
            self.clamp();
        }
        changed
    }

    fn reparse(&mut self) {
        let q = self.input.value().to_string();
        match self.opts.mode {
            Mode::Fuzzy => {
                let append = q.starts_with(&self.last_query) && !self.last_query.is_empty();
                self.nucleo.pattern.reparse(0, &q, CaseMatching::Smart, Normalization::Smart, append);
            }
            Mode::Grep => {
                // Stop the old search, drop its results, start over.
                self.cancel.store(true, Ordering::Relaxed);
                self.cancel = Arc::new(AtomicBool::new(false));
                self.nucleo.restart(true);
                grep::spawn(self.opts.root.clone(), q.clone(), self.nucleo.injector(), self.cancel.clone());
            }
        }
        self.last_query = q;
        self.cursor = 0;
        self.offset = 0;
    }

    fn matched(&self) -> u32 {
        self.nucleo.snapshot().matched_item_count()
    }

    fn clamp(&mut self) {
        let n = self.matched();
        if n == 0 {
            self.cursor = 0;
        } else if self.cursor >= n {
            self.cursor = n - 1;
        }
    }

    fn current(&self) -> Option<Candidate> {
        self.nucleo.snapshot().get_matched_item(self.cursor).map(|i| i.data.clone())
    }

    fn move_by(&mut self, delta: i64) {
        let n = i64::from(self.matched());
        if n == 0 {
            return;
        }
        self.cursor = (i64::from(self.cursor) + delta).clamp(0, n - 1) as u32;
    }

    pub fn handle_event(&mut self, ev: &Event) -> Action {
        let Event::Key(KeyEvent { code, modifiers, kind, .. }) = ev else {
            return Action::None;
        };
        if *kind == KeyEventKind::Release {
            return Action::None;
        }
        let ctrl = modifiers.contains(KeyModifiers::CONTROL);
        // `--expect` keys accept and report which key was used.
        if let Some((name, _)) = self.expect.iter().find(|(_, want)| crate::keys::matches(&KeyEvent::new(*code, *modifiers), want)) {
            let name = name.clone();
            let picked: Vec<String> = if self.marked.is_empty() {
                self.current().map(|c| c.output()).into_iter().collect()
            } else {
                self.marked.iter().cloned().collect()
            };
            return Action::AcceptWith(name, picked);
        }
        match code {
            KeyCode::Esc => return Action::Cancel,
            KeyCode::Char('c') | KeyCode::Char('g') if ctrl => return Action::Cancel,
            KeyCode::Enter => {
                let picked: Vec<String> = if self.marked.is_empty() {
                    self.current().map(|c| c.output()).into_iter().collect()
                } else {
                    self.marked.iter().cloned().collect()
                };
                return Action::Accept(picked);
            }
            KeyCode::Up => self.move_by(-1),
            KeyCode::Down => self.move_by(1),
            KeyCode::Char('p') if ctrl => self.move_by(-1),
            KeyCode::Char('n') if ctrl => self.move_by(1),
            KeyCode::Char('d') if ctrl => self.pscroll += (self.pheight / 2).max(1),
            KeyCode::Char('u') if ctrl => self.pscroll = self.pscroll.saturating_sub((self.pheight / 2).max(1)),
            KeyCode::PageUp => self.move_by(-i64::from(self.page)),
            KeyCode::PageDown => self.move_by(i64::from(self.page)),
            KeyCode::Tab => {
                if let Some(c) = self.current().map(|c| c.output()) {
                    if !self.marked.remove(&c) {
                        self.marked.insert(c);
                    }
                    self.move_by(1);
                }
            }
            _ => {
                if self.input.handle_event(ev).is_some() {
                    self.reparse();
                }
            }
        }
        Action::None
    }

    fn git_state(&self, cand: &str) -> Option<(char, git_core::Kind)> {
        let (repo, status) = self.git.as_ref()?;
        let rela = repo.relative(&self.opts.root.join(cand))?;
        let fs = status.get(&rela)?;
        let k = fs.unstaged.or(fs.staged)?;
        let c = match (fs.unstaged, k) {
            (Some(git_core::Kind::Untracked), _) => '?',
            (Some(git_core::Kind::Conflict), _) => 'U',
            (Some(git_core::Kind::Deleted), _) | (None, git_core::Kind::Deleted) => 'D',
            (Some(_), _) => 'M',
            (None, git_core::Kind::Added) => 'A',
            (None, _) => '+',
        };
        Some((c, k))
    }

    /// Name color of a ref, commit or stash row.
    fn git_item_color(theme: &Theme, g: &crate::candidate::GitItem) -> Color {
        use crate::candidate::GitKind::*;
        let c = &theme.colors;
        match g.kind {
            Branch => c.accent,
            Remote => c.info,
            Tag | Commit => c.warning,
            Stash => c.git.conflict,
        }
        .into()
    }

    fn git_color(theme: &Theme, kind: git_core::Kind) -> Color {
        use git_core::Kind::*;
        let g = &theme.colors.git;
        match kind {
            Added => g.added,
            Modified | Typechange => g.modified,
            Deleted => g.deleted,
            Renamed => g.renamed,
            Untracked => g.untracked,
            Conflict => g.conflict,
        }
        .into()
    }

    pub fn render(&mut self, area: Rect, buf: &mut Buffer, theme: &Theme) {
        let (list_area, preview_area) = if self.opts.preview {
            let [l, p] = layout::main_preview(theme, area);
            (l, Some(p))
        } else {
            (area, None)
        };
        self.render_list(list_area, buf, theme);
        if let Some(p) = preview_area {
            self.render_preview(p, buf, theme);
        }
    }

    /// Spans for one row: fuzzy rows highlight matched characters; grep rows
    /// show `path:line:` then the line with the match emphasized.
    fn row_spans(&mut self, cand: &Candidate, name_fg: Color, theme: &Theme, snap_index: u32) -> Vec<Span<'static>> {
        let c = &theme.colors;
        let hit = Style::new().fg(c.accent.into()).add_modifier(Modifier::BOLD);
        if let Some(loc) = &cand.loc {
            let mut spans = vec![
                Span::styled(loc.path.clone(), Style::new().fg(name_fg)),
                Span::styled(format!(":{}: ", loc.line), Style::new().fg(c.muted.into())),
            ];
            let (a, b) = (loc.hit.start, loc.hit.end);
            if a < b && b <= loc.text.len() {
                spans.push(Span::styled(loc.text[..a].to_string(), Style::new().fg(c.fg.into())));
                spans.push(Span::styled(loc.text[a..b].to_string(), hit));
                spans.push(Span::styled(loc.text[b..].to_string(), Style::new().fg(c.fg.into())));
            } else {
                spans.push(Span::styled(loc.text.clone(), Style::new().fg(c.fg.into())));
            }
            return spans;
        }
        let snap = self.nucleo.snapshot();
        let mut indices = Vec::new();
        if let Some(item) = snap.get_matched_item(snap_index) {
            snap.pattern().column_pattern(0).indices(item.matcher_columns[0].slice(..), &mut self.matcher, &mut indices);
        }
        indices.sort_unstable();
        indices.dedup();
        let mut hits = indices.iter().copied().peekable();
        // Git items: the name part takes its kind color, the subject the text color.
        let (name_len, name_color, rest_color) = match &cand.git {
            Some(g) => (g.name.chars().count(), Self::git_item_color(theme, g), Color::from(c.fg)),
            None => (usize::MAX, name_fg, name_fg),
        };
        let mut spans = Vec::new();
        if let Some(g) = &cand.git {
            spans.push(Span::styled(if g.is_head { "* " } else { "  " }, Style::new().fg(c.accent.into())));
        }
        if let Some(b) = &cand.buffer {
            spans.push(Span::styled(format!("{:<2} ", b.flags), Style::new().fg(c.warning.into())));
        }
        for (i, ch) in cand.display.chars().enumerate() {
            let is_hit = hits.peek() == Some(&(i as u32));
            if is_hit {
                hits.next();
            }
            let base = if i < name_len { name_color } else { rest_color };
            spans.push(Span::styled(ch.to_string(), if is_hit { hit } else { Style::new().fg(base) }));
        }
        spans
    }

    fn render_list(&mut self, area: Rect, buf: &mut Buffer, theme: &Theme) {
        let c = &theme.colors;
        let (snap_total, snap_matched) = {
            let s = self.nucleo.snapshot();
            (s.item_count(), s.matched_item_count())
        };
        // In grep mode every item matches, so only the item count is meaningful.
        let count = if self.opts.mode == Mode::Grep { format!("{snap_total}") } else { format!("{snap_matched}/{snap_total}") };
        let title = self.title.as_deref().unwrap_or(if self.opts.mode == Mode::Grep { "grep" } else { "pick" });
        let pane = Pane::new(theme).title(title).focused(true);
        let inner = pane.inner(area);
        pane.render(area, buf);
        if inner.height < 2 {
            return;
        }

        // Prompt row: "> query" with the count flush right.
        let prompt_area = Rect { height: 1, ..inner };
        let prompt = Line::from(vec![
            Span::styled("> ", Style::new().fg(c.accent.into())),
            Span::styled(self.input.value().to_string(), Style::new().fg(c.fg.into())),
        ]);
        Paragraph::new(prompt).render(prompt_area, buf);
        let cw = count.len() as u16;
        if inner.width > cw + 4 {
            buf.set_string(inner.right() - cw, inner.y, &count, Style::new().fg(c.muted.into()));
        }
        // Cursor cell.
        let cx = prompt_area.x + 2 + self.input.visual_cursor() as u16;
        if cx < prompt_area.right() {
            if let Some(cell) = buf.cell_mut((cx, prompt_area.y)) {
                cell.set_style(Style::new().add_modifier(Modifier::REVERSED));
            }
        }

        // Header lines sit between the prompt and the list.
        let header_rows = (self.header.len() as u16).min(inner.height.saturating_sub(2));
        for (i, h) in self.header.iter().take(usize::from(header_rows)).enumerate() {
            buf.set_stringn(inner.x + 2, inner.y + 1 + i as u16, h, usize::from(inner.width.saturating_sub(2)), Style::new().fg(c.muted.into()));
        }
        let list = Rect { y: inner.y + 1 + header_rows, height: inner.height - 1 - header_rows, ..inner };
        self.page = u32::from(list.height).max(1);
        // Keep the cursor inside the window.
        if self.cursor < self.offset {
            self.offset = self.cursor;
        } else if self.cursor >= self.offset + self.page {
            self.offset = self.cursor + 1 - self.page;
        }

        let end = (self.offset + self.page).min(snap_matched);
        for (row, idx) in (self.offset..end).enumerate() {
            let Some(cand) = self.nucleo.snapshot().get_matched_item(idx).map(|i| i.data.clone()) else { break };
            let y = list.y + row as u16;
            let selected = idx == self.cursor;
            let base = if selected { Style::new().bg(c.selection.into()) } else { Style::new() };
            // Row background across the full width.
            let row_area = Rect { y, height: 1, ..list };
            buf.set_style(row_area, base);

            let marked = self.marked.contains(&cand.output());
            let mut spans = vec![Span::styled(
                if marked { "● " } else if selected { "▸ " } else { "  " },
                Style::new().fg(c.accent.into()),
            )];
            let git = self.git_state(cand.path());
            let name_fg = git.map(|(_, k)| Self::git_color(theme, k)).unwrap_or(c.fg.into());
            spans.extend(self.row_spans(&cand, name_fg, theme, idx));
            Paragraph::new(Line::from(spans)).style(base).render(row_area, buf);

            if let Some((ch, kind)) = git {
                let x = list.right().saturating_sub(1);
                buf.set_string(x, y, ch.to_string(), base.fg(Self::git_color(theme, kind)));
            }
        }
    }

    fn render_preview(&mut self, area: Rect, buf: &mut Buffer, theme: &Theme) {
        let cand = self.current();
        let title = cand
            .as_ref()
            .map(|c| match (&c.loc, &c.git) {
                (Some(l), _) => format!("{}:{}", l.path, l.line),
                (_, Some(g)) => g.name.clone(),
                _ => c.display.clone(),
            })
            .unwrap_or_default();
        let pane = Pane::new(theme).title(&title);
        let inner = pane.inner(area);
        pane.render(area, buf);
        let Some(cand) = cand else {
            self.preview = None;
            return;
        };
        if inner.width == 0 || inner.height == 0 {
            return;
        }
        let line = cand.loc.as_ref().map(|l| l.line).unwrap_or(0);
        let id = cand.git.as_ref().map(|g| g.oid.clone()).unwrap_or_else(|| cand.path().to_string());
        let key = (id, line, inner.width, inner.height);
        if self.preview.as_ref().map(|p| &p.key) != Some(&key) {
            let opts = pv::Options {
                width: Some(inner.width),
                height: if cand.git.is_some() { None } else { Some(inner.height) },
                git: self.opts.git,
                focus: cand.loc.as_ref().map(|l| l.line).or(cand.buffer.as_ref().and_then(|b| b.focus)),
            };
            let rendered = match (&cand.git, &cand.buffer) {
                (Some(g), _) => pv::preview_commit(&self.opts.root, &g.oid, theme, &opts),
                // An open buffer: its text as shown in the editor, unsaved changes included.
                (None, Some(b)) => pv::preview_text(std::path::Path::new(cand.path()), b.text.as_bytes(), theme, &opts),
                // Plain text with an external preview command: its output, colors kept.
                (None, None) if self.preview_cmd.is_some() && cand.loc.is_none() => {
                    let line = cand.raw.as_deref().unwrap_or(&cand.display);
                    let out = self.preview_cmd.as_ref().map(|p| p.run(line)).unwrap_or_default();
                    Ok(ui::ansi::parse(&out))
                }
                (None, None) => pv::preview(&self.opts.root.join(cand.path()), theme, &opts),
            };
            let lines = match rendered {
                Ok(l) => l,
                Err(e) => vec![Line::from(Span::styled(e.to_string(), Style::new().fg(theme.colors.muted.into())))],
            };
            self.preview = Some(Preview { key, lines });
            self.pscroll = 0;
        }
        self.pheight = usize::from(inner.height);
        if let Some(p) = &self.preview {
            // Commit and command previews scroll; the rest are already windowed to the pane.
            let scrolls = cand.git.is_some() || (self.preview_cmd.is_some() && cand.loc.is_none() && cand.buffer.is_none());
            let skip = if scrolls { self.pscroll.min(p.lines.len().saturating_sub(1)) } else { 0 };
            if scrolls {
                self.pscroll = skip;
            }
            let shown: Vec<Line<'static>> = p.lines.iter().skip(skip).take(usize::from(inner.height)).cloned().collect();
            Paragraph::new(shown).render(inner, buf);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ratatui::crossterm::event::KeyEvent;

    fn key(code: KeyCode) -> Event {
        Event::Key(KeyEvent::new(code, KeyModifiers::NONE))
    }

    fn picker(items: &[&str], paths: bool, root: PathBuf) -> Picker {
        let opts = PickerOptions { mode: Mode::Fuzzy, paths, root, preview: paths, git: false, query: String::new() };
        let p = Picker::new(opts, Arc::new(|| {}));
        let inj = p.injector();
        for i in items {
            inj.push(Candidate::plain(*i), |c, cols| cols[0] = c.display.as_str().into());
        }
        settle(p)
    }

    fn settle(mut p: Picker) -> Picker {
        for _ in 0..200 {
            if !p.nucleo.tick(20).running {
                break;
            }
        }
        p
    }

    fn type_str(p: &mut Picker, s: &str) {
        for ch in s.chars() {
            p.handle_event(&key(KeyCode::Char(ch)));
        }
        for _ in 0..200 {
            if !p.nucleo.tick(20).running {
                break;
            }
        }
    }

    #[test]
    fn filters_and_accepts_highlighted() {
        let mut p = picker(&["alpha", "beta", "gamma"], false, PathBuf::new());
        assert_eq!(p.matched(), 3);
        type_str(&mut p, "bet");
        assert_eq!(p.matched(), 1);
        assert_eq!(p.handle_event(&key(KeyCode::Enter)), Action::Accept(vec!["beta".into()]));
    }

    #[test]
    fn navigation_clamps_and_tab_marks() {
        let mut p = picker(&["a", "b", "c"], false, PathBuf::new());
        p.handle_event(&key(KeyCode::Up));
        assert_eq!(p.cursor, 0);
        p.handle_event(&key(KeyCode::Tab)); // marks the first and moves down
        p.handle_event(&key(KeyCode::Tab)); // marks the second
        assert_eq!(p.cursor, 2);
        let Action::Accept(v) = p.handle_event(&key(KeyCode::Enter)) else { panic!() };
        assert_eq!(v.len(), 2);
        for _ in 0..10 {
            p.handle_event(&key(KeyCode::Down));
        }
        assert_eq!(p.cursor, 2);
    }

    #[test]
    fn escape_cancels_and_no_match_accepts_nothing() {
        let mut p = picker(&["a"], false, PathBuf::new());
        assert_eq!(p.handle_event(&key(KeyCode::Esc)), Action::Cancel);
        type_str(&mut p, "zzz");
        assert_eq!(p.handle_event(&key(KeyCode::Enter)), Action::Accept(vec![]));
    }

    #[test]
    fn renders_list_and_preview() {
        let d = std::env::temp_dir().join(format!("pick-test-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(&d).unwrap();
        std::fs::write(d.join("hello.txt"), "needle in a haystack\n").unwrap();
        std::fs::write(d.join("other.txt"), "x\n").unwrap();
        let mut p = picker(&["hello.txt", "other.txt"], true, d);
        let area = Rect::new(0, 0, 80, 10);
        let mut buf = Buffer::empty(area);
        p.render(area, &mut buf, &Theme::default());
        let text: String = (0..10).map(|y| (0..80).map(|x| buf[(x, y)].symbol().to_string()).collect::<String>() + "\n").collect();
        assert!(text.contains("hello.txt") && text.contains("other.txt"), "{text}");
        assert!(text.contains("needle in a haystack"), "{text}");
        assert!(text.contains("2/2"), "{text}");
    }
}

#[cfg(test)]
mod source_tests {
    use super::*;

    #[test]
    fn files_source_marks_dirs_only_when_asked() {
        let d = std::env::temp_dir().join(format!("pick-src-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(d.join("sub")).unwrap();
        std::fs::write(d.join("sub/f.txt"), "x").unwrap();
        for (dirs, want) in [(false, 1u32), (true, 2u32)] {
            let opts = PickerOptions { mode: Mode::Fuzzy, paths: true, root: d.clone(), preview: false, git: false, query: String::new() };
            let mut p = Picker::new(opts, Arc::new(|| {}));
            crate::source::spawn_files(p.injector(), d.clone(), dirs);
            for _ in 0..200 {
                std::thread::sleep(std::time::Duration::from_millis(10));
                p.nucleo.tick(10);
                if p.matched() >= want {
                    break;
                }
            }
            assert_eq!(p.matched(), want, "dirs={dirs}");
            assert_eq!(p.nucleo.snapshot().matched_items(..).any(|i| i.data.display == "sub/"), dirs);
        }
    }
}

#[cfg(test)]
mod grep_tests {
    use super::*;
    use ratatui::crossterm::event::KeyEvent;

    fn dir(name: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("pick-grep-{}-{name}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(&d).unwrap();
        std::fs::write(d.join("a.txt"), "one\nneedle here\nthree\n").unwrap();
        std::fs::write(d.join("b.rs"), "fn needle() {}\n").unwrap();
        std::fs::write(d.join("c.txt"), "nothing\n").unwrap();
        d
    }

    fn grep_picker(root: PathBuf, query: &str) -> Picker {
        let opts = PickerOptions { mode: Mode::Grep, paths: false, root, preview: true, git: false, query: query.into() };
        Picker::new(opts, Arc::new(|| {}))
    }

    /// Tick until the item count is `want` and stays there, or give up.
    fn wait_items(p: &mut Picker, want: u32) {
        for _ in 0..300 {
            std::thread::sleep(std::time::Duration::from_millis(10));
            p.nucleo.tick(10);
            if p.nucleo.snapshot().item_count() == want {
                std::thread::sleep(std::time::Duration::from_millis(30));
                p.nucleo.tick(10);
                if p.nucleo.snapshot().item_count() == want {
                    return;
                }
            }
        }
    }

    fn type_str(p: &mut Picker, s: &str) {
        for ch in s.chars() {
            p.handle_event(&Event::Key(KeyEvent::new(KeyCode::Char(ch), KeyModifiers::NONE)));
        }
    }

    #[test]
    fn finds_matches_with_location_and_output_format() {
        let mut p = grep_picker(dir("find"), "needle");
        wait_items(&mut p, 2);
        let all: Vec<Candidate> = p.nucleo.snapshot().matched_items(..).map(|i| i.data.clone()).collect();
        assert_eq!(all.len(), 2);
        let a = all.iter().find(|c| c.path() == "a.txt").unwrap();
        assert_eq!(a.output(), "a.txt:2:1:needle here");
        let loc = a.loc.as_ref().unwrap();
        assert_eq!((loc.line, loc.col, &loc.text[loc.hit.clone()]), (2, 1, "needle"));
        let b = all.iter().find(|c| c.path() == "b.rs").unwrap();
        assert_eq!(b.output(), "b.rs:1:4:fn needle() {}");
    }

    #[test]
    fn changing_the_query_restarts_the_search() {
        let mut p = grep_picker(dir("requery"), "needle");
        wait_items(&mut p, 2);
        type_str(&mut p, " h"); // "needle h" only matches a.txt
        wait_items(&mut p, 1);
        assert_eq!(p.current().unwrap().path(), "a.txt");
        assert_eq!(p.handle_event(&Event::Key(KeyEvent::new(KeyCode::Enter, KeyModifiers::NONE))), Action::Accept(vec!["a.txt:2:1:needle here".into()]));
    }

    #[test]
    fn invalid_regex_falls_back_to_literal() {
        let d = dir("badre");
        std::fs::write(d.join("p.txt"), "call(x)\n").unwrap();
        let mut p = grep_picker(d, "call(");
        wait_items(&mut p, 1);
        assert_eq!(p.current().unwrap().output(), "p.txt:1:1:call(x)");
    }

    #[test]
    fn preview_focuses_the_matching_line() {
        let d = dir("prev");
        let body: String = (1..=60).map(|n| if n == 40 { "needle line\n".to_string() } else { format!("filler {n}\n") }).collect();
        std::fs::write(d.join("big.txt"), body).unwrap();
        let mut p = grep_picker(d, "needle line");
        wait_items(&mut p, 1);
        let area = Rect::new(0, 0, 90, 12);
        let mut buf = Buffer::empty(area);
        p.render(area, &mut buf, &Theme::default());
        let text: String = (0..12).map(|y| (0..90).map(|x| buf[(x, y)].symbol().to_string()).collect::<String>() + "\n").collect();
        assert!(text.contains("big.txt:40"), "{text}");
        assert!(text.contains("needle line"), "{text}");
        assert!(text.contains("filler 38") || text.contains("filler 39"), "{text}");
        assert!(!text.contains("filler 5\n") && !text.contains("filler 1 "), "{text}");
    }

    #[test]
    fn empty_query_lists_nothing() {
        let mut p = grep_picker(dir("empty"), "");
        std::thread::sleep(std::time::Duration::from_millis(50));
        p.nucleo.tick(10);
        assert_eq!(p.nucleo.snapshot().item_count(), 0);
    }
}

#[cfg(test)]
mod git_tests {
    use super::*;
    use crate::source::{GitSource, spawn_git};
    use ratatui::crossterm::event::KeyEvent;
    use std::process::Command;

    fn git(dir: &std::path::Path, args: &[&str]) {
        let ok = Command::new("git")
            .args(["-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false"])
            .args(args)
            .current_dir(dir)
            .env("GIT_CONFIG_GLOBAL", "/dev/null")
            .env("GIT_CONFIG_SYSTEM", "/dev/null")
            .status()
            .unwrap()
            .success();
        assert!(ok, "git {args:?}");
    }

    fn repo(name: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("pick-git-{}-{name}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(&d).unwrap();
        git(&d, &["init", "-q", "-b", "main"]);
        std::fs::write(d.join("a.txt"), "one\n").unwrap();
        git(&d, &["add", "."]);
        git(&d, &["commit", "-q", "-m", "first commit"]);
        git(&d, &["tag", "v1"]);
        std::fs::write(d.join("a.txt"), "one\ntwo\n").unwrap();
        git(&d, &["commit", "-qam", "add the second line"]);
        d.canonicalize().unwrap()
    }

    fn picker(root: &PathBuf, what: GitSource, query: &str) -> Picker {
        let opts = PickerOptions { mode: Mode::Fuzzy, paths: false, root: root.clone(), preview: true, git: false, query: query.into() };
        let mut p = Picker::new(opts, Arc::new(|| {}));
        spawn_git(p.injector(), root.clone(), what);
        for _ in 0..300 {
            std::thread::sleep(std::time::Duration::from_millis(10));
            p.nucleo.tick(10);
            if p.nucleo.snapshot().item_count() > 0 && !p.nucleo.tick(10).running {
                break;
            }
        }
        p
    }

    fn enter(p: &mut Picker) -> Action {
        p.handle_event(&Event::Key(KeyEvent::new(KeyCode::Enter, KeyModifiers::NONE)))
    }

    #[test]
    fn refs_list_branches_and_tags_and_print_names() {
        let d = repo("refs");
        let mut p = picker(&d, GitSource::Refs, "");
        let names: Vec<String> = p.nucleo.snapshot().matched_items(..).map(|i| i.data.git.as_ref().unwrap().name.clone()).collect();
        assert_eq!(names, vec!["main".to_string(), "v1".to_string()]);
        assert_eq!(enter(&mut p), Action::Accept(vec!["main".into()])); // head branch is first
    }

    #[test]
    fn query_matches_name_or_subject() {
        let d = repo("query");
        let mut p = picker(&d, GitSource::Refs, "first");
        for _ in 0..50 {
            p.nucleo.tick(10);
        }
        // The tag points at "first commit": found through the subject.
        assert_eq!(enter(&mut p), Action::Accept(vec!["v1".into()]));
    }

    #[test]
    fn commits_print_full_hash_and_preview_shows_the_commit() {
        let d = repo("commits");
        let mut p = picker(&d, GitSource::Commits, "");
        let log = git_core::Repo::discover(&d).unwrap().commits(5).unwrap();
        assert_eq!(log.len(), 2);
        let Action::Accept(v) = enter(&mut p) else { panic!() };
        assert_eq!(v, vec![log[0].oid.clone()]);
        assert_eq!(v[0].len(), 40);

        let area = Rect::new(0, 0, 100, 16);
        let mut buf = Buffer::empty(area);
        p.render(area, &mut buf, &Theme::default());
        let text: String = (0..16).map(|y| (0..100).map(|x| buf[(x, y)].symbol().to_string()).collect::<String>() + "\n").collect();
        assert!(text.contains("add the second line"), "{text}");
        assert!(text.contains("author") && text.contains("1 file changed, +1 -0"), "{text}");
    }

    #[test]
    fn commit_preview_scrolls_with_ctrl_d_and_u() {
        let d = repo("scroll");
        // A commit with a long patch.
        let body: String = (1..=80).map(|n| format!("line {n}\n")).collect();
        std::fs::write(d.join("long.txt"), body).unwrap();
        git(&d, &["add", "."]);
        git(&d, &["commit", "-q", "-m", "long file"]);
        let mut p = picker(&d, GitSource::Commits, "");
        let area = Rect::new(0, 0, 100, 16);
        let draw = |p: &mut Picker| -> String {
            let mut buf = Buffer::empty(area);
            p.render(area, &mut buf, &Theme::default());
            (0..16).map(|y| (0..100).map(|x| buf[(x, y)].symbol().to_string()).collect::<String>() + "\n").collect()
        };
        let top = draw(&mut p);
        assert!(top.contains("long file") && !top.contains("line 70"), "{top}");
        let ctrl = |c| Event::Key(KeyEvent::new(KeyCode::Char(c), KeyModifiers::CONTROL));
        for _ in 0..12 {
            p.handle_event(&ctrl('d'));
            draw(&mut p);
        }
        let deep = draw(&mut p);
        assert!(deep.contains("line 70") || deep.contains("line 7"), "{deep}");
        for _ in 0..40 {
            p.handle_event(&ctrl('u'));
        }
        assert!(draw(&mut p).contains("long file"));
        // Moving to another commit resets the scroll.
        p.handle_event(&ctrl('d'));
        draw(&mut p);
        p.handle_event(&Event::Key(KeyEvent::new(KeyCode::Down, KeyModifiers::NONE)));
        draw(&mut p);
        assert_eq!(p.pscroll, 0);
    }

    #[test]
    fn stashes_print_their_name() {
        let d = repo("stash");
        std::fs::write(d.join("a.txt"), "wip\n").unwrap();
        git(&d, &["stash", "push", "-q", "-m", "work in progress"]);
        let mut p = picker(&d, GitSource::Stashes, "");
        assert_eq!(enter(&mut p), Action::Accept(vec!["stash@{0}".into()]));
    }
}

#[cfg(test)]
mod buffer_tests {
    use super::*;
    use crate::candidate::Buffer as BufferInfo;
    use ratatui::crossterm::event::KeyEvent;

    fn buf(value: &str, flags: &str, path: Option<&str>, focus: Option<u32>, text: &str) -> Candidate {
        Candidate::buffer(
            path.unwrap_or("[scratch]"),
            BufferInfo { value: value.into(), path: path.map(Into::into), flags: flags.into(), focus, text: text.into() },
        )
    }

    fn picker(root: std::path::PathBuf, items: Vec<Candidate>) -> Picker {
        let opts = PickerOptions { mode: Mode::Fuzzy, paths: true, root, preview: true, git: false, query: String::new() };
        let mut p = Picker::new(opts, Arc::new(|| {}));
        let inj = p.injector();
        for c in items {
            inj.push(c, |c, cols| cols[0] = c.display.as_str().into());
        }
        for _ in 0..100 {
            if !p.nucleo.tick(10).running {
                break;
            }
        }
        p.set_cursor(0);
        p
    }

    fn draw(p: &mut Picker) -> String {
        let area = Rect::new(0, 0, 100, 14);
        let mut b = Buffer::empty(area);
        p.render(area, &mut b, &Theme::default());
        (0..14).map(|y| (0..100).map(|x| b[(x, y)].symbol().to_string()).collect::<String>() + "\n").collect()
    }

    #[test]
    fn buffers_show_flags_preview_unsaved_text_and_print_their_id() {
        let d = std::env::temp_dir().join(format!("pick-buf-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(&d).unwrap();
        std::fs::write(d.join("a.txt"), "on disk\n").unwrap();
        let mut p = picker(
            d,
            vec![
                buf("7", "+*", Some("a.txt"), Some(2), "first\nUNSAVED edit\nthird\n"),
                buf("3", "", None, None, "scratch text\n"),
            ],
        );
        let text = draw(&mut p);
        assert!(text.contains("+*") && text.contains("a.txt") && text.contains("[scratch]"), "{text}");
        assert!(text.contains("UNSAVED edit") && !text.contains("on disk"), "{text}");
        // Accepting returns the id the host gave, not the display text.
        assert_eq!(p.handle_event(&Event::Key(KeyEvent::new(KeyCode::Enter, KeyModifiers::NONE))), Action::Accept(vec!["7".into()]));
    }

    #[test]
    fn set_cursor_preselects_the_previous_buffer_and_clamps() {
        let d = std::env::temp_dir();
        let mut p = picker(d.clone(), vec![buf("1", "*", Some("a"), None, "x"), buf("2", "", Some("b"), None, "y"), buf("3", "", Some("c"), None, "z")]);
        p.set_cursor(1);
        assert_eq!(p.handle_event(&Event::Key(KeyEvent::new(KeyCode::Enter, KeyModifiers::NONE))), Action::Accept(vec!["2".into()]));
        p.set_cursor(99);
        assert_eq!(p.handle_event(&Event::Key(KeyEvent::new(KeyCode::Enter, KeyModifiers::NONE))), Action::Accept(vec!["3".into()]));
    }
}

#[cfg(test)]
mod cmd_tests {
    use super::*;
    use ratatui::crossterm::event::KeyEvent;

    fn picker(lines: &[&str]) -> Picker {
        let opts = PickerOptions { mode: Mode::Fuzzy, paths: false, root: std::env::temp_dir(), preview: false, git: false, query: String::new() };
        let mut p = Picker::new(opts, Arc::new(|| {}));
        crate::source::push_candidates(&p.injector(), lines.iter().map(|l| Candidate::plain(*l)).collect());
        p.set_cursor(0);
        p
    }

    fn draw(p: &mut Picker) -> String {
        let area = Rect::new(0, 0, 100, 12);
        let mut b = Buffer::empty(area);
        p.render(area, &mut b, &Theme::default());
        (0..12).map(|y| (0..100).map(|x| b[(x, y)].symbol().to_string()).collect::<String>() + "\n").collect()
    }

    #[test]
    fn plain_lists_have_no_preview_until_a_command_is_set() {
        let mut p = picker(&["alpha one", "beta two"]);
        let before = draw(&mut p);
        assert!(!before.contains("PREVIEW"), "{before}");
        p.set_preview_command("printf 'PREVIEW of %s' {2}", None);
        let after = draw(&mut p);
        assert!(after.contains("PREVIEW of one"), "{after}");
        // Moving the cursor re-runs the command for the new line.
        p.handle_event(&Event::Key(KeyEvent::new(KeyCode::Down, KeyModifiers::NONE)));
        assert!(draw(&mut p).contains("PREVIEW of two"));
    }

    #[test]
    fn command_output_keeps_colors_and_scrolls() {
        let mut p = picker(&["x"]);
        p.set_preview_command("i=1; while [ $i -le 40 ]; do printf '\\033[31mrow %s\\033[0m\\n' $i; i=$((i+1)); done", None);
        let first = draw(&mut p);
        assert!(first.contains("row 1") && !first.contains("row 30"), "{first}");
        for _ in 0..6 {
            p.handle_event(&Event::Key(KeyEvent::new(KeyCode::Char('d'), KeyModifiers::CONTROL)));
            draw(&mut p);
        }
        let scrolled = draw(&mut p);
        assert!(scrolled.contains("row 40") && !scrolled.contains("row 1\n") && !scrolled.contains("row 5 "), "{scrolled}");
    }

    #[test]
    fn title_overrides_the_default() {
        let mut p = picker(&["a"]);
        assert!(draw(&mut p).contains("pick"));
        p.set_title("History");
        assert!(draw(&mut p).contains("History"));
    }

    #[test]
    fn dirs_only_source_lists_just_folders() {
        let d = std::env::temp_dir().join(format!("pick-dirs-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(d.join("a/b")).unwrap();
        std::fs::write(d.join("a/file.txt"), "x").unwrap();
        let opts = PickerOptions { mode: Mode::Fuzzy, paths: true, root: d.clone(), preview: false, git: false, query: String::new() };
        let mut p = Picker::new(opts, Arc::new(|| {}));
        crate::source::spawn_dirs(p.injector(), d);
        for _ in 0..200 {
            std::thread::sleep(std::time::Duration::from_millis(10));
            p.nucleo.tick(10);
            if p.nucleo.snapshot().item_count() >= 2 {
                break;
            }
        }
        let mut names: Vec<String> = p.nucleo.snapshot().matched_items(..).map(|i| i.data.display.clone()).collect();
        names.sort();
        assert_eq!(names, vec!["a/".to_string(), "a/b/".to_string()]);
    }
}

#[cfg(test)]
mod shell_tests {
    use super::*;
    use crate::source::LineFormat;
    use ratatui::crossterm::event::KeyEvent;

    fn picker_from(lines: &[&str], fmt: LineFormat) -> Picker {
        let opts = PickerOptions { mode: Mode::Fuzzy, paths: false, root: std::env::temp_dir(), preview: false, git: false, query: String::new() };
        let mut p = Picker::new(opts, Arc::new(|| {}));
        let items: Vec<Candidate> = lines
            .iter()
            .map(|l| match fmt.with_nth {
                Some(n) => Candidate::with_raw(l.split_whitespace().nth(n - 1).unwrap_or(""), *l),
                None => Candidate::plain(*l),
            })
            .collect();
        crate::source::push_candidates(&p.injector(), items);
        p.set_cursor(0);
        p
    }

    fn key(code: KeyCode, m: KeyModifiers) -> Event {
        Event::Key(KeyEvent::new(code, m))
    }

    fn draw(p: &mut Picker) -> String {
        let area = Rect::new(0, 0, 100, 12);
        let mut b = Buffer::empty(area);
        p.render(area, &mut b, &Theme::default());
        (0..12).map(|y| (0..100).map(|x| b[(x, y)].symbol().to_string()).collect::<String>() + "\n").collect()
    }

    #[test]
    fn expect_keys_accept_and_report_the_key() {
        let mut p = picker_from(&["alpha", "beta"], LineFormat::default());
        p.set_expect(&["ctrl-e".to_string(), "f2".to_string()]).unwrap();
        assert_eq!(p.handle_event(&key(KeyCode::Char('e'), KeyModifiers::CONTROL)), Action::AcceptWith("ctrl-e".into(), vec!["alpha".into()]));
        p.handle_event(&key(KeyCode::Down, KeyModifiers::NONE));
        assert_eq!(p.handle_event(&key(KeyCode::F(2), KeyModifiers::NONE)), Action::AcceptWith("f2".into(), vec!["beta".into()]));
        // Enter still accepts normally, and a plain `e` still types.
        assert_eq!(p.handle_event(&key(KeyCode::Enter, KeyModifiers::NONE)), Action::Accept(vec!["beta".into()]));
        assert!(p.set_expect(&["bogus-key".to_string()]).is_err());
    }

    #[test]
    fn header_lines_sit_under_the_prompt_and_are_not_candidates() {
        let mut p = picker_from(&["row one", "row two"], LineFormat::default());
        p.set_header(vec!["ID   NAME   STATUS".to_string()]);
        let text = draw(&mut p);
        let lines: Vec<&str> = text.lines().collect();
        let h = lines.iter().position(|l| l.contains("ID   NAME   STATUS")).expect("header drawn");
        let r = lines.iter().position(|l| l.contains("row one")).expect("rows drawn");
        assert!(h < r && lines[1].contains('>'), "{text}");
        assert!(text.contains("2/2"), "{text}");
    }

    #[test]
    fn with_nth_shows_one_field_but_prints_and_previews_the_whole_line() {
        let mut p = picker_from(&["nginx\t/nix/store/aaa-nginx", "curl\t/nix/store/bbb-curl"], LineFormat { with_nth: Some(1), delimiter: None });
        p.set_preview_command("printf 'PATH=%s' {2}", None);
        let text = draw(&mut p);
        assert!(text.contains("nginx") && !text.contains("aaa-nginx\n") , "{text}");
        assert!(text.contains("PATH=/nix/store/aaa-nginx"), "{text}");
        assert_eq!(p.handle_event(&key(KeyCode::Enter, KeyModifiers::NONE)), Action::Accept(vec!["nginx\t/nix/store/aaa-nginx".into()]));
    }
}
