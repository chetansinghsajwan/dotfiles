//! Commit preview: header, message, and the files it changed with line counts.

use crate::git::{self, Kind, PatchKind, Repo};
use crate::{Error, Options};
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use std::path::Path;
use ui::Theme;
use unicode_width::UnicodeWidthStr;

/// `YYYY-MM-DD HH:MM` in UTC from seconds since the epoch.
fn utc(secs: i64) -> String {
    let days = secs.div_euclid(86_400);
    let rem = secs.rem_euclid(86_400);
    // Civil-from-days (Howard Hinnant).
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z.rem_euclid(146_097);
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let day = doy - (153 * mp + 2) / 5 + 1;
    let month = if mp < 10 { mp + 3 } else { mp - 9 };
    let year = yoe + era * 400 + i64::from(month <= 2);
    format!("{year:04}-{month:02}-{day:02} {:02}:{:02}", rem / 3600, rem % 3600 / 60)
}

fn age(secs: i64) -> String {
    let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(secs);
    match (now - secs).max(0) {
        0..=59 => "now".into(),
        s @ 60..=3599 => format!("{}m ago", s / 60),
        s @ 3600..=86_399 => format!("{}h ago", s / 3600),
        s @ 86_400..=2_591_999 => format!("{}d ago", s / 86_400),
        s => format!("{}mo ago", s / 2_592_000),
    }
}

fn sign(kind: Kind) -> char {
    match kind {
        Kind::Added => 'A',
        Kind::Deleted => 'D',
        Kind::Renamed => 'R',
        _ => 'M',
    }
}

/// Preview of `rev` (hash, ref name or stash entry) in the repository at `root`.
pub fn render(root: &Path, rev: &str, theme: &Theme, opts: &Options) -> Result<Vec<Line<'static>>, Error> {
    let repo = Repo::discover(root).ok_or(Error::NotFound)?;
    let info = repo.commit(rev).map_err(|e| Error::Unsupported(e.to_string()))?;
    let changes = repo.changes(rev).map_err(|e| Error::Unsupported(e.to_string()))?;

    let c = &theme.colors;
    let muted = Style::new().fg(c.muted.into());
    let fg = Style::new().fg(c.fg.into());
    let label = |s: &str| Span::styled(format!("{s:<7}"), muted);

    let mut out = vec![
        Line::from(vec![label("commit"), Span::styled(info.oid.clone(), Style::new().fg(c.warning.into()))]),
        Line::from(vec![label("author"), Span::styled(format!("{} <{}>", info.author, info.email), fg)]),
        Line::from(vec![label("date"), Span::styled(format!("{} UTC  ({})", utc(info.time), age(info.time)), fg)]),
        Line::default(),
    ];
    for (i, l) in info.message.lines().enumerate() {
        let style = if i == 0 { fg.add_modifier(Modifier::BOLD) } else { fg };
        out.push(Line::from(Span::styled(format!("  {l}"), style)));
    }
    out.push(Line::default());

    let (added, removed): (u32, u32) = changes.iter().fold((0, 0), |(a, r), f| (a + f.added, r + f.removed));
    out.push(Line::from(Span::styled(
        format!("{} file{} changed, +{added} -{removed}", changes.len(), if changes.len() == 1 { "" } else { "s" }),
        muted,
    )));
    for f in &changes {
        let kind_color = git::kind_color(theme, f.kind);
        let left = format!(" {} {}", sign(f.kind), f.path);
        let stat = if f.binary { "binary".to_string() } else { format!("+{} -{}", f.added, f.removed) };
        let mut spans = vec![
            Span::styled(format!(" {} ", sign(f.kind)), Style::new().fg(kind_color)),
            Span::styled(f.path.clone(), Style::new().fg(kind_color)),
        ];
        if let Some(w) = opts.width {
            let pad = (w as usize).saturating_sub(left.width() + stat.width() + 1).max(1);
            spans.push(Span::raw(" ".repeat(pad)));
        } else {
            spans.push(Span::raw("  "));
        }
        if f.binary {
            spans.push(Span::styled(stat, muted));
        } else {
            spans.push(Span::styled(format!("+{}", f.added), Style::new().fg(c.git.added.into())));
            spans.push(Span::raw(" "));
            spans.push(Span::styled(format!("-{}", f.removed), Style::new().fg(c.git.deleted.into())));
        }
        out.push(Line::from(spans));
    }
    let limit = opts.height.map(usize::from).unwrap_or(MAX_LINES);
    if out.len() < limit {
        let rest = limit - out.len();
        out.extend(patch_lines(&repo, rev, theme, opts, rest));
    }
    out.truncate(limit);
    Ok(out)
}


/// Most lines drawn when the caller gives no height.
const MAX_LINES: usize = 4000;

/// The patch under the file list: a header per file, `@@` hunk headers, and
/// added/removed rows tinted across the full width.
fn patch_lines(repo: &Repo, rev: &str, theme: &Theme, opts: &Options, limit: usize) -> Vec<Line<'static>> {
    let c = &theme.colors;
    let Ok(files) = repo.patch(rev) else { return Vec::new() };
    let mut out: Vec<Line<'static>> = Vec::new();
    let digits = files
        .iter()
        .flat_map(|f| &f.hunks)
        .map(|h| h.old_start.max(h.new_start) + h.old_len.max(h.new_len))
        .max()
        .unwrap_or(1)
        .to_string()
        .len();
    let pad_to = |spans: &mut Vec<Span<'static>>, bg: ratatui::style::Color| {
        let used: usize = spans.iter().map(|s| s.content.width()).sum();
        if let Some(w) = opts.width {
            spans.push(Span::raw(" ".repeat((w as usize).saturating_sub(used))));
        }
        for s in spans.iter_mut() {
            s.style = s.style.bg(bg);
        }
    };

    for f in &files {
        if out.len() >= limit {
            break;
        }
        out.push(Line::default());
        let kind_color = git::kind_color(theme, f.kind);
        out.push(Line::from(vec![
            Span::styled(format!("{} ", sign(f.kind)), Style::new().fg(kind_color)),
            Span::styled(f.path.clone(), Style::new().fg(c.accent.into()).add_modifier(Modifier::BOLD)),
        ]));
        if f.binary {
            out.push(Line::from(Span::styled("  binary file not shown", Style::new().fg(c.muted.into()))));
            continue;
        }
        for h in &f.hunks {
            out.push(Line::from(Span::styled(
                format!("@@ -{},{} +{},{} @@", h.old_start, h.old_len, h.new_start, h.new_len),
                Style::new().fg(c.info.into()),
            )));
            let (mut old_no, mut new_no) = (h.old_start, h.new_start);
            for l in &h.lines {
                if out.len() >= limit {
                    return out;
                }
                let text = l.text.replace('\t', "    ");
                let (no, sign, color, tint) = match l.kind {
                    PatchKind::Context => {
                        let n = new_no;
                        old_no += 1;
                        new_no += 1;
                        (n, ' ', c.fg, None)
                    }
                    PatchKind::Added => {
                        let n = new_no;
                        new_no += 1;
                        (n, '+', c.git.added, Some(git::tint(theme, c.git.added.into())))
                    }
                    PatchKind::Removed => {
                        let n = old_no;
                        old_no += 1;
                        (n, '-', c.git.deleted, Some(git::tint(theme, c.git.deleted.into())))
                    }
                };
                let mut spans = vec![
                    Span::styled(format!("{no:>digits$} "), Style::new().fg(c.muted.into())),
                    Span::styled(sign.to_string(), Style::new().fg(color.into())),
                    Span::styled(format!(" {text}"), Style::new().fg(c.fg.into())),
                ];
                if let Some(bg) = tint {
                    pad_to(&mut spans, bg);
                }
                out.push(Line::from(spans));
            }
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::utc;

    #[test]
    fn formats_utc() {
        assert_eq!(utc(0), "1970-01-01 00:00");
        assert_eq!(utc(1_793_108_415), "2026-10-27 13:40");
        assert_eq!(utc(951_782_400 + 3600 * 5 + 60 * 7), "2000-02-29 05:07"); // leap day
    }
}
