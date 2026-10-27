use git_core::{Repo, Status};
use nucleo::pattern::{CaseMatching, Normalization};
use nucleo::{Config, Injector, Matcher, Nucleo};
use ratatui::buffer::Buffer;
use ratatui::crossterm::event::{Event, KeyCode, KeyEvent, KeyEventKind, KeyModifiers};
use ratatui::layout::Rect;
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Paragraph, Widget};
use std::collections::BTreeSet;
use std::path::PathBuf;
use std::sync::Arc;
use tui_input::Input;
use tui_input::backend::crossterm::EventHandler;
use ui::{Pane, Theme, layout};

#[derive(Debug, Clone)]
pub struct PickerOptions {
    /// Candidates are paths relative to `root`: path-aware scoring, preview and git state.
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
    /// The user accepted: the marked candidates, or the highlighted one.
    Accept(Vec<String>),
    Cancel,
}

struct Preview {
    key: (String, u16, u16),
    lines: Vec<Line<'static>>,
}

pub struct Picker {
    opts: PickerOptions,
    nucleo: Nucleo<String>,
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
}

impl Picker {
    /// `notify` is called from worker threads when results changed; the host
    /// should wake its event loop and call `tick`.
    pub fn new(opts: PickerOptions, notify: Arc<dyn Fn() + Send + Sync>) -> Self {
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
            opts,
        };
        picker.reparse();
        picker
    }

    pub fn injector(&self) -> Injector<String> {
        self.nucleo.injector()
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
        let append = q.starts_with(&self.last_query) && !self.last_query.is_empty();
        self.nucleo.pattern.reparse(0, &q, CaseMatching::Smart, Normalization::Smart, append);
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

    fn current(&self) -> Option<String> {
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
        match code {
            KeyCode::Esc => return Action::Cancel,
            KeyCode::Char('c') | KeyCode::Char('g') if ctrl => return Action::Cancel,
            KeyCode::Enter => {
                let picked: Vec<String> = if self.marked.is_empty() {
                    self.current().into_iter().collect()
                } else {
                    self.marked.iter().cloned().collect()
                };
                return Action::Accept(picked);
            }
            KeyCode::Up => self.move_by(-1),
            KeyCode::Down => self.move_by(1),
            KeyCode::Char('p') if ctrl => self.move_by(-1),
            KeyCode::Char('n') if ctrl => self.move_by(1),
            KeyCode::PageUp => self.move_by(-i64::from(self.page)),
            KeyCode::PageDown => self.move_by(i64::from(self.page)),
            KeyCode::Tab => {
                if let Some(c) = self.current() {
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

    fn git_color(theme: &Theme, kind: git_core::Kind) -> ratatui::style::Color {
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

    fn render_list(&mut self, area: Rect, buf: &mut Buffer, theme: &Theme) {
        let c = &theme.colors;
        let snap_total;
        let snap_matched;
        {
            let s = self.nucleo.snapshot();
            snap_total = s.item_count();
            snap_matched = s.matched_item_count();
        }
        let count = format!("{snap_matched}/{snap_total}");
        let pane = Pane::new(theme).title("pick").focused(true);
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

        let list = Rect { y: inner.y + 1, height: inner.height - 1, ..inner };
        self.page = u32::from(list.height).max(1);
        // Keep the cursor inside the window.
        if self.cursor < self.offset {
            self.offset = self.cursor;
        } else if self.cursor >= self.offset + self.page {
            self.offset = self.cursor + 1 - self.page;
        }

        let snap = self.nucleo.snapshot();
        let end = (self.offset + self.page).min(snap_matched);
        let mut indices = Vec::new();
        for (row, idx) in (self.offset..end).enumerate() {
            let Some(item) = snap.get_matched_item(idx) else { break };
            let y = list.y + row as u16;
            let selected = idx == self.cursor;
            let base = if selected { Style::new().bg(c.selection.into()) } else { Style::new() };
            // Row background across the full width.
            buf.set_style(Rect { y, height: 1, ..list }, base);

            let mut spans = Vec::new();
            let marked = self.marked.contains(item.data);
            spans.push(Span::styled(
                if marked { "● " } else if selected { "▸ " } else { "  " },
                Style::new().fg(c.accent.into()),
            ));
            let git = self.git_state(item.data);
            let name_fg = git.map(|(_, k)| Self::git_color(theme, k)).unwrap_or(c.fg.into());

            indices.clear();
            snap.pattern().column_pattern(0).indices(item.matcher_columns[0].slice(..), &mut self.matcher, &mut indices);
            indices.sort_unstable();
            indices.dedup();
            let mut hit = indices.iter().copied().peekable();
            for (i, ch) in item.data.chars().enumerate() {
                let is_hit = hit.peek() == Some(&(i as u32));
                if is_hit {
                    hit.next();
                }
                let style = if is_hit {
                    Style::new().fg(c.accent.into()).add_modifier(Modifier::BOLD)
                } else {
                    Style::new().fg(name_fg)
                };
                spans.push(Span::styled(ch.to_string(), style));
            }
            Paragraph::new(Line::from(spans)).style(base).render(Rect { y, height: 1, ..list }, buf);

            if let Some((ch, kind)) = git {
                let x = list.right().saturating_sub(1);
                buf.set_string(x, y, ch.to_string(), base.fg(Self::git_color(theme, kind)));
            }
        }
    }

    fn render_preview(&mut self, area: Rect, buf: &mut Buffer, theme: &Theme) {
        let cand = self.current();
        let title = cand.clone().unwrap_or_default();
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
        let key = (cand.clone(), inner.width, inner.height);
        if self.preview.as_ref().map(|p| &p.key) != Some(&key) {
            let path = self.opts.root.join(&cand);
            let opts = pv::Options { width: Some(inner.width), height: Some(inner.height), git: self.opts.git };
            let lines = match pv::preview(&path, theme, &opts) {
                Ok(l) => l,
                Err(e) => vec![Line::from(Span::styled(e.to_string(), Style::new().fg(theme.colors.muted.into())))],
            };
            self.preview = Some(Preview { key, lines });
        }
        if let Some(p) = &self.preview {
            Paragraph::new(p.lines.clone()).render(inner, buf);
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
        let opts = PickerOptions { paths, root, preview: paths, git: false, query: String::new() };
        let p = Picker::new(opts, Arc::new(|| {}));
        let inj = p.injector();
        for i in items {
            inj.push(i.to_string(), |s, cols| cols[0] = s.as_str().into());
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
            let opts = PickerOptions { paths: true, root: d.clone(), preview: false, git: false, query: String::new() };
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
            assert_eq!(p.nucleo.snapshot().matched_items(..).any(|i| i.data.as_str() == "sub/"), dirs);
        }
    }
}
