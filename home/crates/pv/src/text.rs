//! Syntax-highlighted text with a line-number gutter.

use crate::git::{self, LineKind, Repo};
use crate::{Error, Options};
use ratatui::style::Color;
use unicode_width::UnicodeWidthStr;
use ratatui::style::Style;
use ratatui::text::{Line, Span};
use std::io::Read;
use std::path::Path;
use std::str::FromStr;
use syntect::easy::HighlightLines;
use syntect::highlighting::{
    Color as SColor, ScopeSelectors, Theme as SynTheme, ThemeItem, ThemeSettings, StyleModifier,
};
use syntect::parsing::SyntaxSet;
use ui::Theme;

/// Cap on bytes read, so a huge file never stalls a preview.
const MAX_BYTES: u64 = 1 << 20;
const TAB: &str = "    ";

fn rgb(c: ui::theme::Hex) -> SColor {
    match c.0 {
        ratatui::style::Color::Rgb(r, g, b) => SColor { r, g, b, a: 255 },
        _ => SColor { r: 255, g: 255, b: 255, a: 255 },
    }
}

/// Build a syntect theme from the design tokens, so highlighting follows them.
fn syntax_theme(t: &Theme) -> SynTheme {
    let s = &t.colors.syntax;
    let rules: &[(&str, ui::theme::Hex)] = &[
        ("comment", s.comment),
        ("keyword, storage", s.keyword),
        ("entity.name.function, support.function, meta.function-call", s.function),
        ("string", s.string),
        ("constant.numeric", s.number),
        ("entity.name.type, entity.name.class, support.type, support.class, storage.type", s.type_),
        ("constant, support.constant", s.constant),
        ("variable", s.variable),
        ("keyword.operator", s.operator),
    ];
    let scopes = rules
        .iter()
        .filter_map(|(sel, c)| {
            Some(ThemeItem {
                scope: ScopeSelectors::from_str(sel).ok()?,
                style: StyleModifier { foreground: Some(rgb(*c)), ..Default::default() },
            })
        })
        .collect();
    SynTheme {
        settings: ThemeSettings {
            foreground: Some(rgb(t.colors.fg)),
            ..Default::default()
        },
        scopes,
        ..Default::default()
    }
}

fn is_binary(buf: &[u8]) -> bool {
    buf.iter().take(8000).any(|&b| b == 0)
}

/// Per-line git marks (index = 0-based line) from changes vs HEAD.
fn line_marks(path: &Path, total: usize) -> Vec<Option<(LineKind, char)>> {
    let mut marks = vec![None; total];
    let Some(repo) = Repo::discover(path) else { return marks };
    let Ok(changes) = repo.line_changes(path) else { return marks };
    for c in changes {
        match c.kind {
            LineKind::Deleted => {
                // Removed lines have no row: mark the line after (or the last one).
                if total == 0 {
                    continue;
                }
                let (row, ch) = if (c.start as usize) < total { (c.start as usize, '▔') } else { (total - 1, '▁') };
                marks[row].get_or_insert((LineKind::Deleted, ch));
            }
            kind => {
                for l in c.start..=c.end {
                    if let Some(m) = marks.get_mut(l as usize - 1) {
                        *m = Some((kind, '▎'));
                    }
                }
            }
        }
    }
    marks
}

pub fn render(path: &Path, theme: &Theme, opts: &Options) -> Result<Vec<Line<'static>>, Error> {
    let mut buf = Vec::new();
    std::fs::File::open(path)?.take(MAX_BYTES).read_to_end(&mut buf)?;
    render_bytes(path, &buf, theme, opts, opts.git)
}

/// Render `buf` as the contents of `path` (which only picks the syntax and,
/// with `git_marks`, the file to compare against `HEAD`). Used for text that
/// is not on disk as shown, e.g. an editor buffer with unsaved changes.
pub fn render_bytes(path: &Path, buf: &[u8], theme: &Theme, opts: &Options, git_marks: bool) -> Result<Vec<Line<'static>>, Error> {
    let buf = &buf[..buf.len().min(MAX_BYTES as usize)];
    if is_binary(buf) {
        return Err(Error::Unsupported("binary".into()));
    }
    let text = String::from_utf8_lossy(buf);

    let syntaxes: SyntaxSet = two_face::syntax::extra_newlines();
    let syntax = syntaxes
        .find_syntax_for_file(path)
        .ok()
        .flatten()
        .or_else(|| text.lines().next().and_then(|l| syntaxes.find_syntax_by_first_line(l)))
        .unwrap_or_else(|| syntaxes.find_syntax_plain_text());
    let syn_theme = syntax_theme(theme);
    let mut hl = HighlightLines::new(syntax, &syn_theme);

    let limit = opts.height.map(usize::from).unwrap_or(usize::MAX);
    let total = text.lines().count();
    let digits = total.max(1).to_string().len();
    let gutter = Style::new().fg(theme.colors.muted.into());
    let marks = if git_marks && opts.git { line_marks(path, total) } else { Vec::new() };
    // With a focus line and a height, show a window centered on it.
    let start = match (opts.focus, opts.height) {
        (Some(f), Some(_)) => {
            let centered = (f as usize).saturating_sub(1).saturating_sub(limit / 2);
            centered.min(total.saturating_sub(limit))
        }
        _ => 0,
    };

    let mut out = Vec::new();
    for (i, raw) in syntect::util::LinesWithEndings::from(&text).enumerate() {
        if i >= start.saturating_add(limit) {
            break;
        }
        // Lines before the window still feed the highlighter's state.
        let regions = hl.highlight_line(raw, &syntaxes).map_err(|e| Error::Unsupported(e.to_string()))?;
        if i < start {
            continue;
        }
        let mark = marks.get(i).copied().flatten();
        let mut spans = Vec::new();
        if opts.git {
            // Sign column: a bar in the change color, blank otherwise.
            spans.push(match mark {
                Some((kind, ch)) => Span::styled(ch.to_string(), Style::new().fg(git::line_color(theme, kind))),
                None => Span::raw(" "),
            });
        }
        spans.push(Span::styled(format!("{:>digits$} ", i + 1), gutter));
        for (st, piece) in regions {
            let piece = piece.trim_end_matches(['\n', '\r']).replace('\t', TAB);
            if piece.is_empty() {
                continue;
            }
            let fg = st.foreground;
            spans.push(Span::styled(piece, Style::new().fg(Color::Rgb(fg.r, fg.g, fg.b))));
        }
        // The focus line wins over a git tint; both span the full width.
        let row_bg = if opts.focus == Some(i as u32 + 1) {
            Some(Color::from(theme.colors.selection))
        } else if let Some((kind @ (LineKind::Added | LineKind::Modified), _)) = mark {
            Some(git::tint(theme, git::line_color(theme, kind)))
        } else {
            None
        };
        if let Some(bg) = row_bg {
            let used: usize = spans.iter().map(|s| s.content.width()).sum();
            if let Some(w) = opts.width {
                spans.push(Span::raw(" ".repeat((w as usize).saturating_sub(used))));
            }
            for s in &mut spans {
                s.style = s.style.bg(bg);
            }
        }
        out.push(Line::from(spans));
    }
    Ok(out)
}
