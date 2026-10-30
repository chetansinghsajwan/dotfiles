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

/// The git logo, for git panes (yazi's color for git files).
pub const GIT: Icon = Icon { glyph: "\u{e702}", color: rgb(0xf54d27) };

const DIR: Icon = Icon { glyph: "\u{e5ff}", color: rgb(0x03a9f4) };
const DIR_OPEN: Icon = Icon { glyph: "\u{e5fe}", color: rgb(0x03a9f4) };
const EXEC: Icon = Icon { glyph: "\u{f489}", color: rgb(0x8bc34a) };
const FILE: Icon = Icon { glyph: "\u{f15b}", color: rgb(0xffffff) };

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
    fn lookup_order() {
        assert_eq!(file("Cargo.toml", false), find(FILES, "cargo.toml").unwrap_or_else(|| find(EXTS, "toml").unwrap()));
        assert_eq!(file("main.RS", false), find(EXTS, "rs").unwrap());
        assert_eq!(file("noext", false), FILE);
        assert_eq!(file("run", true), EXEC);
        assert_eq!(dir(".git", false), find(DIRS, ".git").unwrap());
        assert_eq!(dir("src", true), DIR_OPEN);
    }
}
