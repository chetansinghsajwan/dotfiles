//! Compact directory tree: the folder's entries, and under each subfolder at
//! most two entries then a `…` marker. Right column: permissions + age.

use crate::{Error, Options};
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use std::fs;
use std::path::Path;
use std::time::SystemTime;
use ui::Theme;
use unicode_width::UnicodeWidthStr;

const SUB_LIMIT: usize = 2;

struct Entry {
    name: String,
    is_dir: bool,
    mode: u32,
    mtime: Option<SystemTime>,
    path: std::path::PathBuf,
}

fn entries(dir: &Path) -> Vec<Entry> {
    let mut v: Vec<Entry> = fs::read_dir(dir)
        .into_iter()
        .flatten()
        .flatten()
        .filter_map(|e| {
            let md = e.metadata().ok()?;
            #[cfg(unix)]
            let mode = std::os::unix::fs::PermissionsExt::mode(&md.permissions());
            #[cfg(not(unix))]
            let mode = 0;
            Some(Entry {
                name: e.file_name().to_string_lossy().into_owned(),
                is_dir: md.is_dir(),
                mode,
                mtime: md.modified().ok(),
                path: e.path(),
            })
        })
        .collect();
    v.sort_by(|a, b| b.is_dir.cmp(&a.is_dir).then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase())));
    v
}

fn relative(t: Option<SystemTime>) -> String {
    let Some(t) = t else { return "-".into() };
    let secs = SystemTime::now().duration_since(t).map(|d| d.as_secs()).unwrap_or(0);
    match secs {
        0..=59 => "now".into(),
        60..=3599 => format!("{}m ago", secs / 60),
        3600..=86399 => format!("{}h ago", secs / 3600),
        86400..=2_591_999 => format!("{}d ago", secs / 86400),
        _ => format!("{}mo ago", secs / 2_592_000),
    }
}

fn perm_spans(mode: u32, theme: &Theme) -> Vec<Span<'static>> {
    let c = &theme.colors;
    let mut out = Vec::new();
    for i in 0..9 {
        let bit = 8 - i;
        let set = mode & (1 << bit) != 0;
        let ch = ['r', 'w', 'x'][i % 3];
        let (text, color) = if !set {
            ('-', c.muted)
        } else if i >= 3 {
            (ch, c.muted)
        } else {
            (ch, match ch { 'r' => c.success, 'w' => c.warning, _ => c.error })
        };
        out.push(Span::styled(text.to_string(), Style::new().fg(color.into())));
        if i == 2 || i == 5 {
            out.push(Span::raw(" "));
        }
    }
    out
}

fn row(prefix: &str, e: &Entry, width: Option<u16>, theme: &Theme) -> Line<'static> {
    let c = &theme.colors;
    let name = if e.is_dir { format!("{}/", e.name) } else { e.name.clone() };
    let name_style = if e.is_dir {
        Style::new().fg(c.accent.into()).add_modifier(Modifier::BOLD)
    } else {
        Style::new().fg(c.fg.into())
    };
    let mut spans = vec![
        Span::styled(prefix.to_string(), Style::new().fg(c.muted.into())),
        Span::styled(name.clone(), name_style),
    ];
    if let Some(w) = width {
        let mut right = perm_spans(e.mode, theme);
        right.push(Span::styled(format!("  {:>8}", relative(e.mtime)), Style::new().fg(c.muted.into())));
        let right_w: usize = right.iter().map(|s| s.content.width()).sum();
        let left_w = prefix.width() + name.width();
        let pad = (w as usize).saturating_sub(left_w + right_w + 2).max(1);
        spans.push(Span::raw(" ".repeat(pad)));
        spans.extend(right);
    }
    Line::from(spans)
}

pub fn render(path: &Path, theme: &Theme, opts: &Options) -> Result<Vec<Line<'static>>, Error> {
    let limit = opts.height.map(usize::from).unwrap_or(usize::MAX);
    let top = entries(path);
    let mut out = Vec::new();
    for (i, e) in top.iter().enumerate() {
        if out.len() >= limit {
            break;
        }
        let last = i + 1 == top.len();
        out.push(row(if last { "└── " } else { "├── " }, e, opts.width, theme));
        if e.is_dir {
            let kids = entries(&e.path);
            let lead = if last { "    " } else { "│   " };
            for (j, k) in kids.iter().take(SUB_LIMIT).enumerate() {
                let more = kids.len() > SUB_LIMIT;
                let last_kid = j + 1 == SUB_LIMIT.min(kids.len()) && !more;
                let glyph = if last_kid { "└── " } else { "├── " };
                out.push(row(&format!("{lead}{glyph}"), k, opts.width, theme));
            }
            if kids.len() > SUB_LIMIT {
                out.push(Line::from(Span::styled(
                    format!("{lead}└── …"),
                    Style::new().fg(theme.colors.muted.into()).add_modifier(Modifier::BOLD),
                )));
            }
        }
    }
    out.truncate(limit);
    Ok(out)
}
