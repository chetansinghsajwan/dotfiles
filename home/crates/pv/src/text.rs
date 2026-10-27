//! Syntax-highlighted text with a line-number gutter.

use crate::{Error, Options};
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

pub fn render(path: &Path, theme: &Theme, opts: &Options) -> Result<Vec<Line<'static>>, Error> {
    let mut buf = Vec::new();
    std::fs::File::open(path)?.take(MAX_BYTES).read_to_end(&mut buf)?;
    if is_binary(&buf) {
        return Err(Error::Unsupported("binary".into()));
    }
    let text = String::from_utf8_lossy(&buf);

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

    let mut out = Vec::new();
    for (i, raw) in syntect::util::LinesWithEndings::from(&text).take(limit).enumerate() {
        let regions = hl.highlight_line(raw, &syntaxes).map_err(|e| Error::Unsupported(e.to_string()))?;
        let mut spans = vec![Span::styled(format!("{:>digits$} ", i + 1), gutter)];
        for (st, piece) in regions {
            let piece = piece.trim_end_matches(['\n', '\r']).replace('\t', TAB);
            if piece.is_empty() {
                continue;
            }
            let fg = st.foreground;
            spans.push(Span::styled(piece, Style::new().fg(ratatui::style::Color::Rgb(fg.r, fg.g, fg.b))));
        }
        out.push(Line::from(spans));
    }
    Ok(out)
}
