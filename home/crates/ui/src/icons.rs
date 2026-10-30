//! File icons (Nerd Font glyphs) and their colors, the same set yazi ships.
//! Data in `icons_data.rs` is generated from yazi's preset theme (MIT).

use crate::icons_data::{DIRS, EXTS, FILES};
use ratatui::style::Color;
use std::path::Path;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Icon {
    pub glyph: &'static str,
    pub color: Color,
}

const fn rgb(c: u32) -> Color {
    Color::Rgb((c >> 16) as u8, (c >> 8) as u8, c as u8)
}

/// A git branch, for branch rows.
pub const BRANCH: Icon = Icon { glyph: "\u{e0a0}", color: rgb(0xf54d27) };

/// A git commit, for commit rows.
pub const COMMIT: Icon = Icon { glyph: "\u{f417}", color: rgb(0xe8a838) };

/// An archive box, for stash rows.
pub const STASH: Icon = Icon { glyph: "\u{f187}", color: rgb(0x6d8086) };

/// The git logo, for git panes (yazi's color for git files).
pub const GIT: Icon = Icon { glyph: "\u{e702}", color: rgb(0xf54d27) };

/// A warning triangle, for the diagnostics pane.
pub const DIAGNOSTICS: Icon = Icon { glyph: "\u{f071}", color: rgb(0xffc107) };

const DIR: Icon = Icon { glyph: "\u{e5ff}", color: rgb(0x03a9f4) };
const DIR_OPEN: Icon = Icon { glyph: "\u{e5fe}", color: rgb(0x03a9f4) };
const EXEC: Icon = Icon { glyph: "\u{f489}", color: rgb(0x8bc34a) };
const FILE: Icon = Icon { glyph: "\u{f15b}", color: rgb(0xffffff) };

/// An icon for a well-known pane title (`Files`, `History`, `Branches`, `Buffers`, ...), so
/// pickers and panels look alike whatever tool opens them. Case does not matter.
pub fn for_title(title: &str) -> Option<Icon> {
    let t = title.to_lowercase();
    let has = |words: &[&str]| words.iter().any(|w| t.contains(w));
    let icon = |glyph: &'static str, color: u32| Some(Icon { glyph, color: rgb(color) });
    if has(&["propert"]) {
        icon("\u{f05a}", 0x59c2ff)
    } else if has(&["branch", "refs", "tags"]) {
        Some(BRANCH)
    } else if has(&["history", "commit", "stash", "log", "changes", "changed", "status"]) {
        Some(GIT)
    } else if has(&["diagnostic", "problem"]) {
        Some(DIAGNOSTICS)
    } else if has(&["buffer"]) {
        icon("\u{f0c5}", 0x6d8086)
    } else if has(&["jump"]) {
        icon("\u{f0e2}", 0x6d8086)
    } else if has(&["symbol"]) {
        icon("\u{f1b2}", 0xa074c4)
    } else if has(&["theme"]) {
        icon("\u{f1fc}", 0xf245fb)
    } else if has(&["action"]) {
        icon("\u{f0eb}", 0xffc107)
    } else if has(&["command"]) {
        icon("\u{f120}", 0x89e051)
    } else if has(&["register"]) {
        icon("\u{f0ea}", 0x6d8086)
    } else if has(&["file", "find", "open"]) {
        Some(DIR_OPEN)
    } else if has(&["grep", "search", "pick"]) {
        icon("\u{f002}", 0x59c2ff)
    } else {
        None
    }
}

fn find(table: &[(&'static str, &'static str, u32)], key: &str) -> Option<Icon> {
    let i = table.binary_search_by(|(n, _, _)| (*n).cmp(key)).ok()?;
    let (_, glyph, color) = table[i];
    Some(Icon { glyph, color: rgb(color) })
}

/// Icon for a folder; `open` picks the open-folder glyph (expanded or hovered).
pub fn dir(name: &str, open: bool) -> Icon {
    match find(DIRS, &name.to_lowercase()) {
        Some(i) => i,
        None if open => DIR_OPEN,
        None => DIR,
    }
}

/// Icon for a file by exact name, then extension; executables fall back to the
/// executable glyph.
pub fn file(name: &str, executable: bool) -> Icon {
    let lower = name.to_lowercase();
    if let Some(i) = find(FILES, &lower) {
        return i;
    }
    if let Some(ext) = Path::new(&lower).extension().and_then(|e| e.to_str()) {
        if let Some(i) = find(EXTS, ext) {
            return i;
        }
    }
    if executable { EXEC } else { FILE }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tables_are_sorted() {
        for t in [DIRS, FILES, EXTS] {
            assert!(t.windows(2).all(|w| w[0].0 < w[1].0));
        }
    }

    #[test]
    fn titles_get_icons_whatever_the_case() {
        assert_eq!(for_title("History"), Some(GIT));
        assert_eq!(for_title("history"), for_title("HISTORY"));
        assert_eq!(for_title("Files"), Some(DIR_OPEN));
        assert!(for_title("Branches").is_some() && for_title("Buffers").is_some() && for_title("grep").is_some());
        assert_ne!(for_title("Branches"), for_title("History"));
        assert_eq!(for_title("something else"), None);
    }

    #[test]
    fn lookup_order() {
        assert_eq!(file("Cargo.toml", false), find(FILES, "cargo.toml").unwrap_or_else(|| find(EXTS, "toml").unwrap()));
        assert_eq!(file("main.RS", false), find(EXTS, "rs").unwrap());
        assert_eq!(file("noext", false), FILE);
        assert_eq!(file("run", true), EXEC);
        assert_eq!(dir(".git", false), find(DIRS, ".git").unwrap());
        assert_eq!(dir("src", true), DIR_OPEN);
    }
}
