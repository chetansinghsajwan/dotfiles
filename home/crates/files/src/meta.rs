//! File properties (the metadata panel): permissions, owner, size, times, links,
//! type, and one extra row for images and CSV files. Folder sizes are counted on
//! a background thread so a big tree never blocks the UI.

use chrono::{DateTime, Local};
use ratatui::buffer::Buffer;
use ratatui::layout::Rect;
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Paragraph, Widget};
use std::fs;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::time::SystemTime;
use ui::{Pane, Theme};

/// Rows of the panel (without its border), the most it ever shows.
pub const MAX_ROWS: u16 = 9;

pub struct Meta {
    pub name: String,
    /// Where a symlink points, and whether that target is missing.
    pub link: Option<(String, bool)>,
    /// `rwxr-xr-x` style, nine characters (Unix only).
    pub perm: Option<String>,
    pub owner: Option<String>,
    pub is_dir: bool,
    pub size: u64,
    pub modified: Option<SystemTime>,
    pub created: Option<SystemTime>,
    pub links: Option<u64>,
    pub mime: String,
    /// A label and value for the type-specific row.
    pub extra: Option<(&'static str, String)>,
}

impl Meta {
    pub fn read(path: &Path) -> std::io::Result<Meta> {
        let sym = fs::symlink_metadata(path)?;
        let is_link = sym.file_type().is_symlink();
        let meta = fs::metadata(path).unwrap_or_else(|_| sym.clone());
        let link = is_link.then(|| (fs::read_link(path).map(|t| t.display().to_string()).unwrap_or_default(), fs::metadata(path).is_err()));
        let is_dir = meta.is_dir();
        let mime = if is_dir { "inode/directory".to_string() } else { mime_of(path) };
        let extra = if is_dir { None } else { extra_of(path, &mime) };
        let (perm, owner, links) = unix(&meta);
        Ok(Meta {
            name: path.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_else(|| path.display().to_string()),
            link,
            perm,
            owner,
            is_dir,
            size: meta.len(),
            modified: meta.modified().ok(),
            created: meta.created().ok(),
            links,
            mime,
            extra,
        })
    }

    /// The rows to draw. `dir_size` is `(bytes so far, finished)` for a folder.
    pub fn lines(&self, theme: &Theme, dir_size: Option<(u64, bool)>) -> Vec<Line<'static>> {
        let c = &theme.colors;
        let dim = Style::new().fg(c.muted.into());
        let label = |t: &str| Span::styled(format!("{t:<9}"), dim);
        let val = |t: String| Span::styled(t, Style::new().fg(c.fg.into()));

        let mut name = vec![Span::styled(self.name.clone(), Style::new().fg(c.fg.into()).add_modifier(Modifier::BOLD))];
        if let Some((target, orphan)) = &self.link {
            if *orphan {
                name[0].style = Style::new().fg(c.error.into()).add_modifier(Modifier::CROSSED_OUT);
            }
            name.push(Span::styled(" -> ", dim));
            name.push(val(target.clone()));
        }

        let size = if self.is_dir {
            match dir_size {
                Some((n, true)) => human(n),
                Some((n, false)) => format!("+{}", human(n)),
                None => "…".into(),
            }
        } else {
            human(self.size)
        };

        let mut lines = vec![Line::from(name)];
        if let Some(p) = &self.perm {
            let mut spans = vec![label("Perm")];
            for (i, ch) in p.chars().enumerate() {
                let color = match ch {
                    's' | 'S' | 't' | 'T' => c.info,
                    _ if i >= 3 => c.muted,
                    'r' => c.success,
                    'w' => c.warning,
                    'x' => c.error,
                    _ => c.muted,
                };
                spans.push(Span::styled(ch.to_string(), Style::new().fg(color.into())));
                if i == 2 || i == 5 {
                    spans.push(Span::raw(" "));
                }
            }
            lines.push(Line::from(spans));
        }
        if let Some(o) = &self.owner {
            lines.push(Line::from(vec![label("Owner"), val(o.clone())]));
        }
        lines.push(Line::from(vec![label("Size"), val(size)]));
        lines.push(Line::from(vec![label("Modified"), val(time(self.modified))]));
        lines.push(Line::from(vec![label("Created"), val(time(self.created))]));
        if let Some(n) = self.links {
            lines.push(Line::from(vec![label("Links"), val(n.to_string())]));
        }
        lines.push(Line::from(vec![label("Type"), val(self.mime.clone())]));
        if let Some((l, v)) = &self.extra {
            lines.push(Line::from(vec![label(l), val(v.clone())]));
        }
        lines
    }

    /// Rows `lines` will return at most, to size the pane.
    pub fn height(&self) -> u16 {
        (self.lines(&Theme::default(), None).len() as u16).min(MAX_ROWS)
    }
}

/// Draw the panel in `area` for `path` (a bordered pane titled "properties").
pub fn render(area: Rect, buf: &mut Buffer, theme: &Theme, meta: Option<&Meta>, dir_size: Option<(u64, bool)>) {
    let pane = Pane::new(theme).title("properties");
    let inner = pane.inner(area);
    pane.render(area, buf);
    if let Some(m) = meta {
        Paragraph::new(m.lines(theme, dir_size)).render(inner, buf);
    }
}

/// Counts the bytes under a folder on a thread; drop or `cancel` it when the
/// cursor moves on.
pub struct DirSize {
    pub path: PathBuf,
    total: Arc<AtomicU64>,
    done: Arc<AtomicBool>,
    cancel: Arc<AtomicBool>,
}

impl DirSize {
    pub fn spawn(path: PathBuf) -> DirSize {
        let d = DirSize { path: path.clone(), total: Arc::new(AtomicU64::new(0)), done: Arc::new(AtomicBool::new(false)), cancel: Arc::new(AtomicBool::new(false)) };
        let (total, done, cancel) = (d.total.clone(), d.done.clone(), d.cancel.clone());
        std::thread::spawn(move || {
            let mut stack = vec![path];
            while let Some(dir) = stack.pop() {
                if cancel.load(Ordering::Relaxed) {
                    return;
                }
                let Ok(entries) = fs::read_dir(&dir) else { continue };
                for e in entries.flatten() {
                    let Ok(t) = e.file_type() else { continue };
                    if t.is_dir() {
                        stack.push(e.path());
                    } else if let Ok(m) = e.metadata() {
                        total.fetch_add(m.len(), Ordering::Relaxed);
                    }
                }
            }
            done.store(true, Ordering::Relaxed);
        });
        d
    }

    /// `(bytes so far, finished)`.
    pub fn state(&self) -> (u64, bool) {
        (self.total.load(Ordering::Relaxed), self.done.load(Ordering::Relaxed))
    }
}

impl Drop for DirSize {
    fn drop(&mut self) {
        self.cancel.store(true, Ordering::Relaxed);
    }
}

/// `rwxr-xr-x` for a Unix mode (dashes where there is none).
pub fn perm_string(mode: u32) -> String {
    let mut p = String::new();
    for (i, (r, w, x)) in [(0o400, 0o200, 0o100), (0o040, 0o020, 0o010), (0o004, 0o002, 0o001)].into_iter().enumerate() {
        let special = [(0o4000, 's', 'S'), (0o2000, 's', 'S'), (0o1000, 't', 'T')][i];
        p.push(if mode & r != 0 { 'r' } else { '-' });
        p.push(if mode & w != 0 { 'w' } else { '-' });
        p.push(match (mode & x != 0, mode & special.0 != 0) {
            (true, true) => special.1,
            (false, true) => special.2,
            (true, false) => 'x',
            _ => '-',
        });
    }
    p
}

/// The Unix mode bits of some metadata (0 elsewhere).
pub fn mode_of(m: &fs::Metadata) -> u32 {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        m.permissions().mode()
    }
    #[cfg(not(unix))]
    {
        let _ = m;
        0
    }
}

/// A folder size for a column: the number so far, with a `+` while still counting.
pub fn size_cell((n, done): (u64, bool)) -> String {
    if done { size_short(n) } else { format!("+{}", size_short(n)) }
}

/// A size in at most five cells for a column: `512`, `1.2K`, `15M`.
pub fn size_short(n: u64) -> String {
    const UNITS: [&str; 5] = ["", "K", "M", "G", "T"];
    let mut v = n as f64;
    let mut i = 0;
    while v >= 1024.0 && i < UNITS.len() - 1 {
        v /= 1024.0;
        i += 1;
    }
    if i == 0 {
        n.to_string()
    } else if v < 10.0 {
        format!("{v:.1}{}", UNITS[i])
    } else {
        format!("{:.0}{}", v, UNITS[i])
    }
}

/// A modification time for a column, 11 cells: `MM-DD HH:MM` this year, `YY-MM-DD` before.
pub fn time_short(t: Option<SystemTime>) -> String {
    let Some(t) = t else { return String::new() };
    let local: DateTime<Local> = t.into();
    if local.format("%Y").to_string() == Local::now().format("%Y").to_string() { local.format("%m-%d %H:%M").to_string() } else { local.format("%y-%m-%d").to_string() }
}

pub fn human(n: u64) -> String {
    const UNITS: [&str; 5] = ["B", "KiB", "MiB", "GiB", "TiB"];
    let mut v = n as f64;
    let mut i = 0;
    while v >= 1024.0 && i < UNITS.len() - 1 {
        v /= 1024.0;
        i += 1;
    }
    if i == 0 { format!("{n} B") } else { format!("{v:.1} {}", UNITS[i]) }
}

fn ago(secs: u64) -> String {
    match secs {
        0..60 => "now".into(),
        60..3600 => format!("{}m ago", secs / 60),
        3600..86_400 => format!("{}h ago", secs / 3600),
        86_400..2_592_000 => format!("{}d ago", secs / 86_400),
        2_592_000..31_536_000 => format!("{}mo ago", secs / 2_592_000),
        _ => format!("{}y ago", secs / 31_536_000),
    }
}

fn time(t: Option<SystemTime>) -> String {
    let Some(t) = t else { return "-".into() };
    let local: DateTime<Local> = t.into();
    let abs = if local.format("%Y").to_string() == Local::now().format("%Y").to_string() { local.format("%b %d %H:%M") } else { local.format("%b %d  %Y") };
    let secs = SystemTime::now().duration_since(t).map(|d| d.as_secs()).unwrap_or(0);
    format!("{abs} ({})", ago(secs))
}

fn mime_of(path: &Path) -> String {
    if let Ok(Some(t)) = infer::get_from_path(path) {
        return t.mime_type().to_string();
    }
    if let Some(m) = mime_guess::from_path(path).first() {
        return m.essence_str().to_string();
    }
    let mut buf = [0u8; 8192];
    match fs::File::open(path).and_then(|mut f| f.read(&mut buf)) {
        Ok(n) if !buf[..n].contains(&0) => "text/plain".into(),
        _ => "application/octet-stream".into(),
    }
}

fn extra_of(path: &Path, mime: &str) -> Option<(&'static str, String)> {
    if mime.starts_with("image/") {
        let s = imagesize::size(path).ok()?;
        return Some(("Dims", format!("{}×{}", s.width, s.height)));
    }
    let ext = path.extension()?.to_str()?.to_lowercase();
    if ext == "csv" || ext == "tsv" {
        let sep = if ext == "csv" { ',' } else { '\t' };
        let mut text = String::new();
        fs::File::open(path).ok()?.take(1 << 20).read_to_string(&mut text).ok()?;
        let rows = text.lines().count();
        let cols = text.lines().next().map_or(0, |l| l.split(sep).count());
        let more = if text.len() as u64 >= 1 << 20 { "+" } else { "" };
        return Some(("CSV", format!("{rows}{more} rows × {cols} cols")));
    }
    None
}

#[cfg(unix)]
fn unix(m: &fs::Metadata) -> (Option<String>, Option<String>, Option<u64>) {
    use std::os::unix::fs::MetadataExt;
    let p = perm_string(mode_of(m));
    let owner = format!("{}:{}", name_for("/etc/passwd", m.uid()), name_for("/etc/group", m.gid()));
    (Some(p), Some(owner), Some(m.nlink()))
}

#[cfg(not(unix))]
fn unix(_: &fs::Metadata) -> (Option<String>, Option<String>, Option<u64>) {
    (None, None, None)
}

/// The name for an id in `/etc/passwd` or `/etc/group`, else the number.
#[cfg(unix)]
fn name_for(file: &str, id: u32) -> String {
    fs::read_to_string(file)
        .ok()
        .and_then(|t| t.lines().find_map(|l| {
            let mut f = l.split(':');
            let (name, _, n) = (f.next()?, f.next()?, f.next()?);
            (n.parse::<u32>().ok()? == id).then(|| name.to_string())
        }))
        .unwrap_or_else(|| id.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn dir(name: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("files-meta-{}-{name}", std::process::id()));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(&d).unwrap();
        d
    }

    fn text(lines: &[Line]) -> Vec<String> {
        lines.iter().map(|l| l.spans.iter().map(|s| s.content.as_ref()).collect()).collect()
    }

    #[test]
    fn human_sizes() {
        assert_eq!(size_short(0), "0");
        assert_eq!(size_short(1536), "1.5K");
        assert_eq!(size_short(15 << 20), "15M");
        assert_eq!(human(0), "0 B");
        assert_eq!(human(1023), "1023 B");
        assert_eq!(human(1536), "1.5 KiB");
        assert_eq!(human(5 << 30), "5.0 GiB");
    }

    #[test]
    fn file_rows_and_csv_extra() {
        let d = dir("rows");
        let f = d.join("t.csv");
        fs::write(&f, "a,b,c\n1,2,3\n4,5,6\n").unwrap();
        let m = Meta::read(&f).unwrap();
        let rows = text(&m.lines(&Theme::default(), None));
        assert_eq!(rows[0], "t.csv");
        assert!(rows.iter().any(|r| r.starts_with("Size") && r.ends_with("18 B")), "{rows:?}");
        assert!(rows.iter().any(|r| r.starts_with("Type") && r.contains("csv")), "{rows:?}");
        assert!(rows.iter().any(|r| r.starts_with("CSV") && r.ends_with("3 rows × 3 cols")), "{rows:?}");
        #[cfg(unix)]
        assert!(rows.iter().any(|r| r.starts_with("Perm") && r.contains("rw")), "{rows:?}");
    }

    #[test]
    fn symlink_shows_target_and_orphans() {
        let d = dir("link");
        fs::write(d.join("real"), "x").unwrap();
        #[cfg(unix)]
        {
            std::os::unix::fs::symlink("real", d.join("ok")).unwrap();
            std::os::unix::fs::symlink("gone", d.join("bad")).unwrap();
            assert_eq!(Meta::read(&d.join("ok")).unwrap().link, Some(("real".into(), false)));
            assert_eq!(Meta::read(&d.join("bad")).unwrap().link, Some(("gone".into(), true)));
        }
    }

    #[test]
    fn folder_size_is_counted_in_the_background() {
        let d = dir("size");
        fs::create_dir_all(d.join("a/b")).unwrap();
        fs::write(d.join("a/x"), vec![0u8; 100]).unwrap();
        fs::write(d.join("a/b/y"), vec![0u8; 50]).unwrap();
        let s = DirSize::spawn(d.clone());
        for _ in 0..200 {
            if s.state().1 {
                break;
            }
            std::thread::sleep(std::time::Duration::from_millis(10));
        }
        assert_eq!(s.state(), (150, true));
        assert_eq!(Meta::read(&d).unwrap().mime, "inode/directory");
    }
}
