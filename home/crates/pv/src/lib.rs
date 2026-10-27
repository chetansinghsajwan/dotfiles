//! `pv`: preview renderer. Library returns ratatui lines so other tools can
//! embed previews in-process; the CLI prints the same lines as ANSI.

mod ansi;
mod config;
mod dir;
mod git;
mod text;

use ratatui::text::Line;
use std::io;
use std::path::Path;
use ui::Theme;

pub use ansi::to_ansi;
pub use config::Config;

#[derive(Debug, Clone)]
pub struct Options {
    /// Preview width in cells (right-aligns directory metadata, pads row tints). `None` = unknown.
    pub width: Option<u16>,
    /// Visible rows. Rendering stops after this many lines. `None` = no limit.
    pub height: Option<u16>,
    /// Git status colors and signs.
    pub git: bool,
    /// 1-based line to bring into view and highlight (text files). The window
    /// is centered on it when it does not fit in `height`.
    pub focus: Option<u32>,
}

impl Default for Options {
    fn default() -> Self {
        Options { width: None, height: None, git: true, focus: None }
    }
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
        let lines = preview(&f, &Theme::default(), &Options { width: None, height: Some(2), git: false, focus: None }).unwrap();
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

    fn git_repo(name: &str) -> std::path::PathBuf {
        let d = tmp(name);
        let run = |args: &[&str]| {
            let ok = std::process::Command::new("git")
                .args(["-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false"])
                .args(args)
                .current_dir(&d)
                .env("GIT_CONFIG_GLOBAL", "/dev/null")
                .env("GIT_CONFIG_SYSTEM", "/dev/null")
                .status()
                .unwrap()
                .success();
            assert!(ok);
        };
        run(&["init", "-q", "-b", "main"]);
        fs::write(d.join("a.txt"), "1\n2\n3\n").unwrap();
        fs::create_dir(d.join("sub")).unwrap();
        fs::write(d.join("sub/s.txt"), "s\n").unwrap();
        run(&["add", "."]);
        run(&["commit", "-q", "-m", "i"]);
        d.canonicalize().unwrap()
    }

    fn flat(l: &Line) -> String {
        l.spans.iter().map(|s| s.content.as_ref()).collect()
    }

    #[test]
    fn text_marks_changed_rows_and_no_git_disables() {
        let d = git_repo("gtext");
        fs::write(d.join("a.txt"), "1\nX\n3\n").unwrap();
        let on = preview(&d.join("a.txt"), &Theme::default(), &Options { width: Some(20), height: None, git: true, focus: None }).unwrap();
        assert!(flat(&on[1]).starts_with('▎'));
        assert!(on[1].spans.iter().skip(1).all(|s| s.style.bg.is_some()), "row tinted");
        assert!(flat(&on[0]).starts_with(' ') && on[0].spans.iter().all(|s| s.style.bg.is_none()));
        let off = preview(&d.join("a.txt"), &Theme::default(), &Options { width: Some(20), height: None, git: false, focus: None }).unwrap();
        assert!(!flat(&off[1]).contains('▎') && off[1].spans.iter().all(|s| s.style.bg.is_none()));
    }

    #[test]
    fn dir_shows_git_signs() {
        let d = git_repo("gdir");
        fs::write(d.join("a.txt"), "changed\n").unwrap();
        fs::write(d.join("sub/new.txt"), "n\n").unwrap();
        let on = preview(&d, &Theme::default(), &Options { width: Some(80), height: None, git: true, focus: None }).unwrap();
        let text: Vec<String> = on.iter().map(flat).collect();
        assert!(text.iter().any(|l| l.contains("sub/") && l.trim_end().ends_with('•')), "{text:?}");
        assert!(text.iter().any(|l| l.contains("a.txt") && l.trim_end().ends_with('M')), "{text:?}");
        let off = preview(&d, &Theme::default(), &Options { width: Some(80), height: None, git: false, focus: None }).unwrap();
        assert!(off.iter().map(flat).all(|l| !l.trim_end().ends_with('M') && !l.trim_end().ends_with('•')));
    }


    #[test]
    fn focus_centers_window_and_highlights_row() {
        let d = tmp("focus");
        let f = d.join("big.txt");
        let body: String = (1..=100).map(|n| format!("line {n}\n")).collect();
        fs::write(&f, body).unwrap();
        let o = Options { width: Some(20), height: Some(10), git: false, focus: Some(50) };
        let lines = preview(&f, &Theme::default(), &o).unwrap();
        assert_eq!(lines.len(), 10);
        let text: Vec<String> = lines.iter().map(flat).collect();
        assert!(text.iter().any(|l| l.contains("line 50")), "{text:?}");
        assert!(text[0].contains("line 45") || text[0].contains("line 46"), "{text:?}");
        let hit = lines.iter().position(|l| flat(l).contains("line 50")).unwrap();
        assert!(lines[hit].spans.iter().all(|s| s.style.bg.is_some()));
        assert_eq!(lines.iter().filter(|l| l.spans.iter().any(|s| s.style.bg.is_some())).count(), 1);
        // Near the end the window is clamped, not padded.
        let o = Options { focus: Some(100), ..o };
        let text: Vec<String> = preview(&f, &Theme::default(), &o).unwrap().iter().map(flat).collect();
        assert!(text.last().unwrap().contains("line 100"), "{text:?}");
        assert_eq!(text.len(), 10);
    }
    #[test]
    fn ansi_resets_after_styled_span() {
        let lines = vec![Line::from(ratatui::text::Span::styled("x", ratatui::style::Style::new().fg(ratatui::style::Color::Rgb(1, 2, 3))))];
        assert_eq!(to_ansi(&lines), "\x1b[38;2;1;2;3mx\x1b[0m\n");
    }
}
