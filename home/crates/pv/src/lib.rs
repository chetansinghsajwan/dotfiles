//! `pv`: preview renderer. Library returns ratatui lines so other tools can
//! embed previews in-process; the CLI prints the same lines as ANSI.

mod ansi;
mod dir;
mod text;

use ratatui::text::Line;
use std::io;
use std::path::Path;
use ui::Theme;

pub use ansi::to_ansi;

#[derive(Debug, Clone, Default)]
pub struct Options {
    /// Preview width in cells (right-aligns directory metadata). `None` = unknown.
    pub width: Option<u16>,
    /// Visible rows. Rendering stops after this many lines. `None` = no limit.
    pub height: Option<u16>,
}

#[derive(Debug)]
pub enum Error {
    Io(io::Error),
    /// Not a regular file or directory.
    NotFound,
    /// Binary or otherwise unrenderable content.
    Unsupported(String),
}

impl From<io::Error> for Error {
    fn from(e: io::Error) -> Self {
        Error::Io(e)
    }
}

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Error::Io(e) => write!(f, "{e}"),
            Error::NotFound => write!(f, "not a file or directory"),
            Error::Unsupported(w) => write!(f, "unsupported file type ({w})"),
        }
    }
}

/// Render a preview of `path`.
pub fn preview(path: &Path, theme: &Theme, opts: &Options) -> Result<Vec<Line<'static>>, Error> {
    let meta = std::fs::metadata(path)?;
    if meta.is_dir() {
        dir::render(path, theme, opts)
    } else if meta.is_file() {
        text::render(path, theme, opts)
    } else {
        Err(Error::NotFound)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    fn tmp(name: &str) -> std::path::PathBuf {
        let d = std::env::temp_dir().join(format!("pv-test-{}-{name}", std::process::id()));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(&d).unwrap();
        d
    }

    #[test]
    fn text_has_gutter_and_respects_height() {
        let d = tmp("text");
        let f = d.join("a.rs");
        fs::write(&f, "fn main() {}\nlet x = 1;\nlet y = 2;\n").unwrap();
        let lines = preview(&f, &Theme::default(), &Options { width: None, height: Some(2) }).unwrap();
        assert_eq!(lines.len(), 2);
        assert!(lines[0].spans[0].content.contains('1'));
    }

    #[test]
    fn binary_is_unsupported() {
        let d = tmp("bin");
        let f = d.join("b");
        fs::write(&f, [0u8, 1, 2, 3]).unwrap();
        assert!(matches!(preview(&f, &Theme::default(), &Options::default()), Err(Error::Unsupported(_))));
    }

    #[test]
    fn dir_lists_dirs_first_and_caps_children() {
        let d = tmp("dir");
        fs::write(d.join("z.txt"), "x").unwrap();
        fs::create_dir(d.join("sub")).unwrap();
        for n in ["1", "2", "3"] {
            fs::write(d.join("sub").join(n), "x").unwrap();
        }
        let lines = preview(&d, &Theme::default(), &Options::default()).unwrap();
        let text: Vec<String> = lines.iter().map(|l| l.spans.iter().map(|s| s.content.as_ref()).collect()).collect();
        assert!(text[0].contains("sub/"));
        assert_eq!(text.iter().filter(|l| l.contains('…')).count(), 1);
        assert!(text.last().unwrap().contains("z.txt"));
    }

    #[test]
    fn ansi_resets_after_styled_span() {
        let lines = vec![Line::from(ratatui::text::Span::styled("x", ratatui::style::Style::new().fg(ratatui::style::Color::Rgb(1, 2, 3))))];
        assert_eq!(to_ansi(&lines), "\x1b[38;2;1;2;3mx\x1b[0m\n");
    }
}
