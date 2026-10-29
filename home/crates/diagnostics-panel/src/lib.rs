//! `diagnostics-panel`: the problems list (errors, warnings, ...) grouped by
//! file, with a severity filter. It knows nothing about any editor: the host
//! hands it a list of `Item`s (it can do so on every frame; an unchanged list
//! costs a comparison) and reacts to the `Action`s.

use ratatui::buffer::Buffer;
use ratatui::crossterm::event::{Event, KeyCode, KeyEvent, KeyEventKind, KeyModifiers};
use ratatui::layout::Rect;
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Paragraph, Widget};
use std::path::{Path, PathBuf};
use ui::{Pane, Theme};
use unicode_width::UnicodeWidthStr;

/// Most severe first (`Error < Warning < ...` in sort order).
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum Severity {
    Error,
    Warning,
    Info,
    Hint,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Item {
    /// Absolute path of the file.
    pub path: PathBuf,
    /// 1-based line and column.
    pub line: u32,
    pub col: u32,
    pub severity: Severity,
    pub message: String,
    /// Who reported it (`rust-analyzer`, `clippy`, ...).
    pub source: Option<String>,
}

/// What the host should do after an event.
#[derive(Debug, PartialEq, Eq)]
pub enum Action {
    None,
    /// Go to this place.
    Open { path: PathBuf, line: u32, col: u32 },
    /// Give the keyboard back (Esc, `q`).
    Close,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Filter {
    All,
    /// Errors and warnings.
    Problems,
    Errors,
}

impl Filter {
    fn next(self) -> Filter {
        match self {
            Filter::All => Filter::Problems,
            Filter::Problems => Filter::Errors,
            Filter::Errors => Filter::All,
        }
    }

    fn keeps(self, s: Severity) -> bool {
        match self {
            Filter::All => true,
            Filter::Problems => s <= Severity::Warning,
            Filter::Errors => s == Severity::Error,
        }
    }

    fn label(self) -> &'static str {
        match self {
            Filter::All => "",
            Filter::Problems => " [errors + warnings]",
            Filter::Errors => " [errors]",
        }
    }
}

enum Row {
    /// A file: the number of problems shown under it.
    File(PathBuf, usize),
    /// Index into `items`.
    Item(usize),
}

pub struct Panel {
    root: PathBuf,
    items: Vec<Item>,
    rows: Vec<Row>,
    /// Indices into `rows` of the selectable rows.
    selectable: Vec<usize>,
    /// Position in `selectable`.
    cursor: usize,
    offset: usize,
    page: usize,
    filter: Filter,
}

impl Panel {
    /// `root`: the workspace; file names are shown relative to it.
    pub fn new(root: impl Into<PathBuf>) -> Panel {
        Panel { root: root.into(), items: Vec::new(), rows: Vec::new(), selectable: Vec::new(), cursor: 0, offset: 0, page: 10, filter: Filter::All }
    }

    /// Replace the list. A list equal to the current one is ignored, so hosts can
    /// call this every frame.
    pub fn set_items(&mut self, mut items: Vec<Item>) {
        items.sort_by(|a, b| a.path.cmp(&b.path).then(a.line.cmp(&b.line)).then(a.col.cmp(&b.col)).then(a.severity.cmp(&b.severity)));
        if items == self.items {
            return;
        }
        let keep = self.current().cloned();
        self.items = items;
        self.rebuild(keep);
    }

    /// (errors, warnings, total) over all items, whatever the filter.
    pub fn counts(&self) -> (usize, usize, usize) {
        let e = self.items.iter().filter(|i| i.severity == Severity::Error).count();
        let w = self.items.iter().filter(|i| i.severity == Severity::Warning).count();
        (e, w, self.items.len())
    }

    fn current(&self) -> Option<&Item> {
        match self.rows.get(*self.selectable.get(self.cursor)?)? {
            Row::Item(i) => self.items.get(*i),
            Row::File(..) => None,
        }
    }

    fn rebuild(&mut self, keep: Option<Item>) {
        self.rows.clear();
        self.selectable.clear();
        let mut last: Option<&Path> = None;
        for (i, it) in self.items.iter().enumerate() {
            if !self.filter.keeps(it.severity) {
                continue;
            }
            if last != Some(it.path.as_path()) {
                last = Some(it.path.as_path());
                self.rows.push(Row::File(it.path.clone(), 0));
            }
            if let Some(Row::File(_, n)) = self.rows.iter_mut().rev().find(|r| matches!(r, Row::File(..))) {
                *n += 1;
            }
            self.selectable.push(self.rows.len());
            self.rows.push(Row::Item(i));
        }
        // Stay on the same problem if it is still there.
        self.cursor = keep
            .and_then(|k| self.selectable.iter().position(|&r| matches!(&self.rows[r], Row::Item(i) if self.items[*i] == k)))
            .unwrap_or(self.cursor)
            .min(self.selectable.len().saturating_sub(1));
    }

    fn move_by(&mut self, delta: isize) {
        let last = self.selectable.len().saturating_sub(1) as isize;
        self.cursor = (self.cursor as isize + delta).clamp(0, last.max(0)) as usize;
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
            KeyCode::End | KeyCode::Char('G') => self.cursor = self.selectable.len().saturating_sub(1),
            KeyCode::Enter | KeyCode::Right | KeyCode::Char('l') => {
                if let Some(it) = self.current() {
                    return Action::Open { path: it.path.clone(), line: it.line, col: it.col };
                }
            }
            KeyCode::Char('f') => {
                let keep = self.current().cloned();
                self.filter = self.filter.next();
                self.rebuild(keep);
            }
            _ => {}
        }
        Action::None
    }

    fn sev_color(theme: &Theme, s: Severity) -> Color {
        let c = &theme.colors;
        match s {
            Severity::Error => c.error,
            Severity::Warning => c.warning,
            Severity::Info => c.info,
            Severity::Hint => c.muted,
        }
        .into()
    }

    fn rel<'a>(&'a self, p: &'a Path) -> &'a Path {
        p.strip_prefix(&self.root).unwrap_or(p)
    }

    pub fn render(&mut self, area: Rect, buf: &mut Buffer, theme: &Theme, focused: bool) {
        let c = &theme.colors;
        let (e, w, _) = self.counts();
        let plural = |n: usize, s: &str| format!("{n} {s}{}", if n == 1 { "" } else { "s" });
        let title = if self.items.is_empty() { "diagnostics".to_string() } else { format!("diagnostics: {}, {}{}", plural(e, "error"), plural(w, "warning"), self.filter.label()) };
        let pane = Pane::new(theme).title(&title).focused(focused);
        let inner = pane.inner(area);
        pane.render(area, buf);
        if inner.height == 0 || inner.width < 6 {
            return;
        }
        if self.rows.is_empty() {
            let msg = if self.items.is_empty() { "no problems" } else { "nothing at this filter (f)" };
            buf.set_string(inner.x + 1, inner.y, msg, Style::new().fg(c.muted.into()));
            return;
        }

        self.page = usize::from(inner.height).max(1);
        let crow = self.selectable.get(self.cursor).copied().unwrap_or(0);
        if crow < self.offset {
            self.offset = crow;
        } else if crow >= self.offset + self.page {
            self.offset = crow + 1 - self.page;
        }
        for (i, row) in self.rows.iter().enumerate().skip(self.offset).take(self.page) {
            let y = inner.y + (i - self.offset) as u16;
            let line_area = Rect { y, height: 1, ..inner };
            match row {
                Row::File(path, n) => {
                    let line = Line::from(vec![
                        Span::styled("▾ ", Style::new().fg(c.muted.into())),
                        Span::styled(self.rel(path).display().to_string(), Style::new().fg(c.accent.into()).add_modifier(Modifier::BOLD)),
                        Span::styled(format!("  {n}"), Style::new().fg(c.muted.into())),
                    ]);
                    Paragraph::new(line).render(line_area, buf);
                }
                Row::Item(idx) => {
                    let it = &self.items[*idx];
                    let selected = i == crow;
                    let base = if selected && focused { Style::new().bg(c.selection.into()) } else { Style::new() };
                    buf.set_style(line_area, base);
                    let head = format!("{}:{}", it.line, it.col);
                    let source = it.source.as_deref().map(|s| format!("  {s}")).unwrap_or_default();
                    // The first line of the message, cut to the room left.
                    let used = 2 + 2 + head.width() + 2 + source.width();
                    let room = usize::from(inner.width).saturating_sub(used);
                    let mut msg: String = it.message.lines().next().unwrap_or("").to_string();
                    if msg.width() > room {
                        let mut cut = String::new();
                        for ch in msg.chars() {
                            if cut.width() + 1 >= room {
                                break;
                            }
                            cut.push(ch);
                        }
                        msg = format!("{cut}…");
                    }
                    let line = Line::from(vec![
                        Span::styled(if selected { "▸ " } else { "  " }, Style::new().fg(c.accent.into())),
                        Span::styled("● ", Style::new().fg(Self::sev_color(theme, it.severity))),
                        Span::styled(head, Style::new().fg(c.muted.into())),
                        Span::raw("  "),
                        Span::styled(msg, Style::new().fg(c.fg.into())),
                        Span::styled(source, Style::new().fg(c.muted.into())),
                    ]);
                    Paragraph::new(line).style(base).render(line_area, buf);
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn item(path: &str, line: u32, sev: Severity, msg: &str) -> Item {
        Item { path: PathBuf::from("/ws").join(path), line, col: 3, severity: sev, message: msg.into(), source: Some("lsp".into()) }
    }

    fn key(c: KeyCode) -> Event {
        Event::Key(KeyEvent::new(c, KeyModifiers::NONE))
    }

    fn sample() -> Vec<Item> {
        vec![
            item("src/b.rs", 20, Severity::Warning, "unused variable `y`"),
            item("src/a.rs", 5, Severity::Error, "expected `;`"),
            item("src/a.rs", 2, Severity::Hint, "consider using `let`"),
            item("src/b.rs", 4, Severity::Error, "mismatched types\nexpected u32"),
            item("README.md", 1, Severity::Info, "a note"),
        ]
    }

    fn draw(p: &mut Panel) -> Vec<String> {
        let area = Rect::new(0, 0, 70, 14);
        let mut b = Buffer::empty(area);
        p.render(area, &mut b, &Theme::default(), true);
        (0..14).map(|y| (0..70).map(|x| b[(x, y)].symbol().to_string()).collect::<String>().trim_end().to_string()).collect()
    }

    #[test]
    fn groups_by_file_sorted_by_path_then_line_with_counts_in_the_title() {
        let mut p = Panel::new("/ws");
        p.set_items(sample());
        let l = draw(&mut p);
        let pos = |s: &str| l.iter().position(|r| r.contains(s)).unwrap_or_else(|| panic!("{s} in {l:#?}"));
        assert!(l[0].contains("diagnostics: 2 errors, 1 warning"), "{}", l[0]);
        assert!(pos("README.md") < pos("a note") && pos("a note") < pos("src/a.rs") && pos("src/a.rs") < pos("2:3") && pos("2:3") < pos("5:3"));
        assert!(pos("5:3") < pos("src/b.rs") && pos("src/b.rs") < pos("4:3") && pos("4:3") < pos("20:3"));
        // Only the first line of a message shows; the source follows it.
        assert!(l[pos("4:3")].contains("mismatched types") && !l.iter().any(|r| r.contains("expected u32")));
        assert!(l[pos("5:3")].contains("expected `;`") && l[pos("5:3")].contains("lsp"));
        // File rows carry their count.
        let body = |s: &str| l[pos(s)].trim_end().trim_end_matches('│').trim_end().to_string();
        assert!(body("src/a.rs").ends_with('2') && body("README.md").ends_with('1'), "{l:#?}");
    }

    #[test]
    fn navigation_skips_file_rows_and_enter_opens_the_place() {
        let mut p = Panel::new("/ws");
        p.set_items(sample());
        assert_eq!(p.handle_event(&key(KeyCode::Enter)), Action::Open { path: "/ws/README.md".into(), line: 1, col: 3 });
        p.handle_event(&key(KeyCode::Down));
        p.handle_event(&key(KeyCode::Char('j')));
        assert_eq!(p.handle_event(&key(KeyCode::Enter)), Action::Open { path: "/ws/src/a.rs".into(), line: 5, col: 3 });
        for _ in 0..9 {
            p.handle_event(&key(KeyCode::Down));
        }
        assert_eq!(p.handle_event(&key(KeyCode::Enter)), Action::Open { path: "/ws/src/b.rs".into(), line: 20, col: 3 });
        p.handle_event(&key(KeyCode::Char('g')));
        assert_eq!(p.handle_event(&key(KeyCode::Esc)), Action::Close);
    }

    #[test]
    fn the_filter_cycles_and_the_cursor_stays_on_the_same_problem() {
        let mut p = Panel::new("/ws");
        p.set_items(sample());
        // Stand on the warning in b.rs.
        p.handle_event(&key(KeyCode::Char('G')));
        assert!(matches!(p.handle_event(&key(KeyCode::Enter)), Action::Open { line: 20, .. }));
        p.handle_event(&key(KeyCode::Char('f'))); // errors + warnings: the hint and the note vanish
        let l = draw(&mut p);
        assert!(l[0].contains("[errors + warnings]") && !l.iter().any(|r| r.contains("a note") || r.contains("let")), "{l:#?}");
        assert!(matches!(p.handle_event(&key(KeyCode::Enter)), Action::Open { line: 20, .. }), "same problem");
        p.handle_event(&key(KeyCode::Char('f'))); // errors only: the warning is gone, the cursor lands on a neighbor
        let l = draw(&mut p);
        assert!(l[0].contains("[errors]") && !l.iter().any(|r| r.contains("unused variable")), "{l:#?}");
        assert!(matches!(p.handle_event(&key(KeyCode::Enter)), Action::Open { .. }));
        p.handle_event(&key(KeyCode::Char('f'))); // back to all
        assert!(draw(&mut p).iter().any(|r| r.contains("a note")));
    }

    #[test]
    fn an_unchanged_list_keeps_state_and_a_changed_one_keeps_the_cursor_on_its_problem() {
        let mut p = Panel::new("/ws");
        p.set_items(sample());
        p.handle_event(&key(KeyCode::Down));
        p.handle_event(&key(KeyCode::Down));
        let at = |p: &mut Panel| match p.handle_event(&key(KeyCode::Enter)) {
            Action::Open { path, line, .. } => (path, line),
            other => panic!("{other:?}"),
        };
        let before = at(&mut p);
        p.set_items(sample()); // same list, any order
        assert_eq!(at(&mut p), before);
        // A new problem appears above: the cursor stays on the problem it was on.
        let mut more = sample();
        more.push(item("src/a.rs", 1, Severity::Error, "new one"));
        p.set_items(more);
        assert_eq!(at(&mut p), before);
        // The problem it was on is fixed: the cursor stays in range.
        p.set_items(vec![item("x.rs", 1, Severity::Error, "only")]);
        assert_eq!(at(&mut p).1, 1);
        p.set_items(vec![]);
        assert_eq!(p.handle_event(&key(KeyCode::Enter)), Action::None);
        assert!(draw(&mut p).iter().any(|r| r.contains("no problems")));
    }

    #[test]
    fn long_messages_are_cut_with_an_ellipsis() {
        let mut p = Panel::new("/ws");
        p.set_items(vec![item("a.rs", 1, Severity::Error, &"very long message ".repeat(20))]);
        let l = draw(&mut p);
        assert!(l.iter().any(|r| r.contains('…') && r.contains("very long")), "{l:#?}");
        assert!(l.iter().all(|r| r.chars().count() <= 70));
    }
}
