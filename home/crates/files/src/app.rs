use files::meta::{self, DirSize, Meta};
use files::{Action, Panel, PanelOptions, Search, ops};
use ratatui::Terminal;
use ratatui::backend::CrosstermBackend;
use ratatui::buffer::Buffer;
use ratatui::crossterm::event::{self, Event, KeyCode, KeyEvent, KeyEventKind, KeyModifiers};
use ratatui::crossterm::execute;
use ratatui::crossterm::terminal::{Clear, ClearType, EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode};
use ratatui::layout::Rect;
use ratatui::style::Style;
use ratatui::text::{Line, Span};
use ratatui::widgets::{Paragraph, Widget};
use std::fs::{self, File, OpenOptions};
use std::io::{self, Read};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::Duration;
use ui::{Pane, Theme};

pub struct Options {
    pub dir: PathBuf,
    pub chooser_file: Option<PathBuf>,
    pub cwd_file: Option<PathBuf>,
    pub hidden: bool,
    pub preview: bool,
    pub git: bool,
}

type Term = Terminal<CrosstermBackend<File>>;

/// The last preview, kept until the cursor, the pane size or the file changes.
struct Preview {
    key: (PathBuf, u16, u16),
    lines: Result<Vec<Line<'static>>, String>,
}

struct App {
    opts: Options,
    theme: Theme,
    tabs: Vec<Panel>,
    active: usize,
    preview: Option<Preview>,
    show_meta: bool,
    meta: Option<(PathBuf, Option<Meta>)>,
    dirsize: Option<DirSize>,
}

pub fn run(opts: Options) -> io::Result<u8> {
    let dir = opts.dir.canonicalize()?;
    let panel_opts = PanelOptions { hidden: opts.hidden, git: opts.git, linemode: files::Linemode::Full, ..PanelOptions::default() };
    let mut app = App { theme: Theme::load(), tabs: vec![Panel::new(dir, panel_opts)], active: 0, preview: None, show_meta: true, meta: None, dirsize: None, opts };

    // Draw on the controlling terminal so stdout stays free for the caller.
    let tty = OpenOptions::new().read(true).write(true).open("/dev/tty")?;
    let mut term: Term = Terminal::new(CrosstermBackend::new(tty))?;
    enter(&mut term)?;
    let result = app.event_loop(&mut term);
    let _ = leave(&mut term);
    if let Some(file) = &app.opts.cwd_file {
        fs::write(file, app.tabs[app.active].root().as_os_str().as_encoded_bytes())?;
    }
    result
}

fn enter(term: &mut Term) -> io::Result<()> {
    enable_raw_mode()?;
    execute!(term.backend_mut(), EnterAlternateScreen, Clear(ClearType::All))?;
    term.clear()
}

fn leave(term: &mut Term) -> io::Result<()> {
    disable_raw_mode()?;
    execute!(term.backend_mut(), LeaveAlternateScreen)
}

/// Give the terminal to `f` (an editor, `pick`, ...) and take it back afterwards.
fn suspended<T>(term: &mut Term, f: impl FnOnce() -> T) -> io::Result<T> {
    leave(term)?;
    let out = f();
    enter(term)?;
    Ok(out)
}

impl App {
    fn panel(&mut self) -> &mut Panel {
        &mut self.tabs[self.active]
    }

    fn event_loop(&mut self, term: &mut Term) -> io::Result<u8> {
        let mut dirty = true;
        let mut shown = None;
        loop {
            if dirty {
                term.draw(|f| {
                    let area = f.area();
                    self.render(area, f.buffer_mut());
                })?;
                shown = self.dirsize.as_ref().map(DirSize::state);
            }
            if !event::poll(Duration::from_millis(100))? {
                // A folder size still being counted changes what is on screen.
                let props = self.dirsize.as_ref().map(DirSize::state) != shown;
                dirty = self.panel().tick() || props;
                continue;
            }
            let ev = event::read()?;
            dirty = true;
            if matches!(ev, Event::Resize(..)) {
                continue;
            }
            if let Some(code) = self.on_event(&ev, term)? {
                return Ok(code);
            }
        }
    }

    /// Handle one event; `Some(code)` quits.
    fn on_event(&mut self, ev: &Event, term: &mut Term) -> io::Result<Option<u8>> {
        let Event::Key(KeyEvent { code, modifiers, kind, .. }) = ev else { return Ok(None) };
        if *kind == KeyEventKind::Release {
            return Ok(None);
        }
        if !self.panel().is_busy() && !modifiers.contains(KeyModifiers::CONTROL) {
            match code {
                KeyCode::Char('i') => {
                    self.show_meta = !self.show_meta;
                    return Ok(None);
                }
                KeyCode::Char('t') => {
                    let root = self.panel().root().to_path_buf();
                    self.tabs.push(Panel::new(root, PanelOptions { hidden: self.opts.hidden, git: self.opts.git, linemode: files::Linemode::Full, ..PanelOptions::default() }));
                    self.active = self.tabs.len() - 1;
                    return Ok(None);
                }
                KeyCode::Char(c @ '1'..='9') => {
                    let i = *c as usize - '1' as usize;
                    if i < self.tabs.len() {
                        self.active = i;
                    }
                    return Ok(None);
                }
                KeyCode::Char('[') => {
                    self.active = (self.active + self.tabs.len() - 1) % self.tabs.len();
                    return Ok(None);
                }
                KeyCode::Char(']') => {
                    self.active = (self.active + 1) % self.tabs.len();
                    return Ok(None);
                }
                _ => {}
            }
        }
        let action = self.panel().handle_event(ev);
        self.act(action, term)
    }

    fn act(&mut self, action: Action, term: &mut Term) -> io::Result<Option<u8>> {
        match action {
            Action::Open(path) => {
                if let Some(file) = &self.opts.chooser_file {
                    fs::write(file, path.as_os_str().as_encoded_bytes())?;
                    return Ok(Some(0));
                }
                let result = suspended(term, || open(&path))?;
                self.report(result);
                self.panel().refresh();
            }
            Action::Close => {
                if self.tabs.len() > 1 {
                    self.tabs.remove(self.active);
                    self.active = self.active.min(self.tabs.len() - 1);
                } else {
                    return Ok(Some(0));
                }
            }
            Action::Search(kind) => {
                let root = self.panel().root().to_path_buf();
                if let Some(found) = suspended(term, || search(kind, &root))? {
                    self.panel().reveal(&found);
                }
            }
            Action::BulkRename(paths) => {
                let root = self.panel().root().to_path_buf();
                let result = suspended(term, || bulk_rename(&root, &paths))?;
                self.panel().clear_marks();
                self.panel().refresh();
                match result {
                    Ok(n) => self.panel().notify(format!("renamed {n} item{}", if n == 1 { "" } else { "s" }), false),
                    Err(e) => self.panel().notify(e, true),
                }
            }
            Action::OpenWith(path, cmd) => {
                let result = suspended(term, || open_with(&cmd, &path))?;
                self.report(result);
                self.panel().refresh();
            }
            Action::None | Action::Created(..) | Action::Moved(_) | Action::Deleted(_) => {}
        }
        Ok(None)
    }

    fn report(&mut self, result: Result<(), String>) {
        if let Err(e) = result {
            self.panel().notify(e, true);
        }
    }

    fn render(&mut self, area: Rect, buf: &mut Buffer) {
        let theme = self.theme.clone();
        let mut body = area;
        if self.tabs.len() > 1 {
            let bar = Rect { height: 1, ..area };
            body = Rect { y: area.y + 1, height: area.height.saturating_sub(1), ..area };
            self.tab_bar(bar, buf);
        }
        let (list, preview) = if self.opts.preview && body.width >= 60 {
            let [l, p] = ui::layout::main_preview(&theme, body);
            (l, Some(p))
        } else {
            (body, None)
        };
        self.tabs[self.active].render(list, buf, &theme, true);
        if let Some(area) = preview {
            self.render_preview(area, buf);
        }
    }

    fn tab_bar(&self, area: Rect, buf: &mut Buffer) {
        let c = &self.theme.colors;
        let mut spans = Vec::new();
        for (i, tab) in self.tabs.iter().enumerate() {
            let name = tab.root().file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_else(|| "/".into());
            let style = if i == self.active { Style::new().fg(c.accent.into()).bold() } else { Style::new().fg(c.muted.into()) };
            spans.push(Span::styled(format!(" {} {name} ", i + 1), style));
        }
        Paragraph::new(Line::from(spans)).render(area, buf);
    }

    fn render_preview(&mut self, area: Rect, buf: &mut Buffer) {
        let current = self.tabs[self.active].current().map(Path::to_path_buf);
        let theme = self.theme.clone();
        let area = self.render_meta(area, buf, current.as_deref());
        let title = current.as_ref().and_then(|p| p.file_name()).map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
        let pane = match current.as_deref() {
            Some(p) if p.is_dir() => Pane::new(&theme).title(&title).icon(ui::icons::dir(&title, false)),
            Some(_) => Pane::new(&theme).title(&title).icon(ui::icons::file(&title, false)),
            None => Pane::new(&theme).title(&title),
        };
        let inner = pane.inner(area);
        pane.render(area, buf);
        let Some(path) = current else { return };
        if inner.width == 0 || inner.height == 0 {
            return;
        }
        let key = (path.clone(), inner.width, inner.height);
        if self.preview.as_ref().is_none_or(|p| p.key != key) {
            let opts = pv::Options { width: Some(inner.width), height: Some(inner.height), git: self.opts.git, focus: None };
            let lines = pv::preview(&path, &theme, &opts).map_err(|e| e.to_string());
            self.preview = Some(Preview { key, lines });
        }
        let lines = match &self.preview.as_ref().expect("set above").lines {
            Ok(lines) => lines.clone(),
            Err(e) => vec![Line::from(Span::styled(e.clone(), Style::new().fg(theme.colors.muted.into())))],
        };
        Paragraph::new(lines).render(inner, buf);
    }
}

fn is_text(path: &Path) -> bool {
    let mut buf = [0u8; 8192];
    File::open(path).and_then(|mut f| f.read(&mut buf)).map(|n| !buf[..n].contains(&0)).unwrap_or(false)
}

/// Open with the editor (text) or the system opener (anything else).
fn open(path: &Path) -> Result<(), String> {
    if is_text(path) {
        let editor = std::env::var("VISUAL").or_else(|_| std::env::var("EDITOR")).unwrap_or_else(|_| "vi".into());
        open_with(&editor, path)
    } else {
        let opener = if cfg!(target_os = "macos") { "open" } else { "xdg-open" };
        Command::new(opener).arg(path).stdin(Stdio::null()).stdout(Stdio::null()).stderr(Stdio::null()).spawn().map(|_| ()).map_err(|e| format!("{opener}: {e}"))
    }
}

/// Run `cmd path` through `sh` and wait for it.
fn open_with(cmd: &str, path: &Path) -> Result<(), String> {
    if cmd.trim().is_empty() {
        return Ok(());
    }
    let script = format!("{cmd} {}", ui::popup::quote(&path.to_string_lossy()));
    match Command::new("sh").arg("-c").arg(script).status() {
        Ok(s) if s.success() => Ok(()),
        Ok(s) => Err(format!("{cmd} exited with {s}")),
        Err(e) => Err(format!("{cmd}: {e}")),
    }
}

/// Run `pick` over `root` and return the chosen path.
fn search(kind: Search, root: &Path) -> Option<PathBuf> {
    let flag = if kind == Search::Files { "--files" } else { "--grep" };
    let out = Command::new("pick").arg(flag).arg(".").current_dir(root).stdin(Stdio::null()).stderr(Stdio::inherit()).output().ok()?;
    if !out.status.success() {
        return None;
    }
    let text = String::from_utf8_lossy(&out.stdout);
    let line = text.lines().next()?;
    // Grep results are `path:line:col:text`.
    let path = if kind == Search::Grep { line.split(':').next()? } else { line };
    Some(root.join(path))
}

/// Edit the names in `$EDITOR`, then rename. Returns how many items changed.
fn bulk_rename(root: &Path, paths: &[PathBuf]) -> Result<usize, String> {
    let tmp = std::env::temp_dir().join(format!("files-rename-{}.txt", std::process::id()));
    fs::write(&tmp, ops::bulk_rename_text(root, paths)).map_err(|e| e.to_string())?;
    let editor = std::env::var("VISUAL").or_else(|_| std::env::var("EDITOR")).unwrap_or_else(|_| "vi".into());
    let edited = open_with(&editor, &tmp).and_then(|()| fs::read_to_string(&tmp).map_err(|e| e.to_string()));
    let _ = fs::remove_file(&tmp);
    let moves = ops::plan_bulk_rename(root, paths, &edited?)?;
    ops::apply_moves(&moves).map_err(|e| e.to_string())?;
    Ok(moves.len())
}

impl App {
    /// Draw the properties pane at the bottom of `area`; returns what is left for the preview.
    fn render_meta(&mut self, area: Rect, buf: &mut Buffer, current: Option<&Path>) -> Rect {
        if !self.show_meta {
            return area;
        }
        if self.meta.as_ref().map(|(p, _)| p.as_path()) != current {
            self.meta = current.map(|p| (p.to_path_buf(), Meta::read(p).ok()));
            self.dirsize = match &self.meta {
                Some((p, Some(m))) if m.is_dir => Some(DirSize::spawn(p.clone())),
                _ => None,
            };
        }
        let rows = self.meta.as_ref().and_then(|(_, m)| m.as_ref()).map_or(1, Meta::height);
        let height = (rows + 2).min(area.height / 2);
        if height < 3 {
            return area;
        }
        let split = Rect { y: area.bottom() - height, height, ..area };
        let meta = self.meta.as_ref().and_then(|(_, m)| m.as_ref());
        meta::render(split, buf, &self.theme, meta, self.dirsize.as_ref().map(DirSize::state));
        Rect { height: area.height - height, ..area }
    }
}
