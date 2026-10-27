//! Design tokens. The single schema every tool reads; produced by Nix
//! (`home/programs/ui`) as `theme.json`, read here at runtime so changing a
//! token needs no rebuild.

use ratatui::style::Color;
use ratatui::widgets::BorderType;
use serde::Deserialize;
use std::path::PathBuf;

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
pub struct Theme {
    pub colors: Colors,
    pub chrome: Chrome,
    pub layout: Layout,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
pub struct Colors {
    pub bg: Hex,
    pub fg: Hex,
    pub muted: Hex,
    pub accent: Hex,
    pub border: Hex,
    pub border_focused: Hex,
    pub selection: Hex,
    pub error: Hex,
    pub warning: Hex,
    pub success: Hex,
    pub info: Hex,
    pub git: GitColors,
    pub syntax: SyntaxColors,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
pub struct GitColors {
    pub added: Hex,
    pub modified: Hex,
    pub deleted: Hex,
    pub untracked: Hex,
    pub conflict: Hex,
    pub renamed: Hex,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
pub struct Chrome {
    /// "rounded" | "plain" | "double" | "thick"
    pub border: String,
    /// Draw the pane title in its border.
    pub titles: bool,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
pub struct Layout {
    /// Cells between adjacent panes.
    pub gap: u16,
    pub padding_x: u16,
    pub padding_y: u16,
    /// Width of a sidebar pane, in cells.
    pub sidebar_width: u16,
    /// Share of the content area given to a preview pane, in percent.
    pub preview_percent: u16,
}

/// A `#rrggbb` color from the JSON.
#[derive(Debug, Clone, Copy)]
pub struct Hex(pub Color);

impl<'de> Deserialize<'de> for Hex {
    fn deserialize<D: serde::Deserializer<'de>>(d: D) -> Result<Self, D::Error> {
        let s = String::deserialize(d)?;
        let h = s.trim_start_matches('#');
        let v = u32::from_str_radix(h, 16).map_err(serde::de::Error::custom)?;
        if h.len() != 6 {
            return Err(serde::de::Error::custom("expected #rrggbb"));
        }
        Ok(Hex(Color::Rgb((v >> 16) as u8, (v >> 8) as u8, v as u8)))
    }
}

impl From<Hex> for Color {
    fn from(h: Hex) -> Color {
        h.0
    }
}

impl Chrome {
    pub fn border_type(&self) -> BorderType {
        match self.border.as_str() {
            "plain" => BorderType::Plain,
            "double" => BorderType::Double,
            "thick" => BorderType::Thick,
            _ => BorderType::Rounded,
        }
    }
}

fn rgb(r: u8, g: u8, b: u8) -> Hex {
    Hex(Color::Rgb(r, g, b))
}

impl Default for Theme {
    fn default() -> Self {
        Theme {
            colors: Colors::default(),
            chrome: Chrome::default(),
            layout: Layout::default(),
        }
    }
}

impl Default for Colors {
    fn default() -> Self {
        Colors {
            bg: rgb(0x0b, 0x0e, 0x14),
            fg: rgb(0xbf, 0xbd, 0xb6),
            muted: rgb(0x5c, 0x67, 0x73),
            accent: rgb(0x59, 0xc2, 0xff),
            border: rgb(0x5c, 0x67, 0x73),
            border_focused: rgb(0x59, 0xc2, 0xff),
            selection: rgb(0x27, 0x37, 0x4d),
            error: rgb(0xf0, 0x71, 0x78),
            warning: rgb(0xe6, 0xb4, 0x50),
            success: rgb(0xaa, 0xd9, 0x4c),
            info: rgb(0x95, 0xe6, 0xcb),
            git: GitColors::default(),
            syntax: SyntaxColors::default(),
        }
    }
}

impl Default for GitColors {
    fn default() -> Self {
        GitColors {
            added: rgb(0xaa, 0xd9, 0x4c),
            modified: rgb(0xe6, 0xb4, 0x50),
            deleted: rgb(0xf0, 0x71, 0x78),
            untracked: rgb(0x95, 0xe6, 0xcb),
            conflict: rgb(0xff, 0x8f, 0x40),
            renamed: rgb(0x59, 0xc2, 0xff),
        }
    }
}

impl Default for Chrome {
    fn default() -> Self {
        Chrome { border: "rounded".into(), titles: true }
    }
}

impl Default for Layout {
    fn default() -> Self {
        Layout { gap: 0, padding_x: 1, padding_y: 0, sidebar_width: 30, preview_percent: 50 }
    }
}

impl Theme {
    /// `$UI_THEME`, else `$XDG_CONFIG_HOME/ui/theme.json`, else `~/.config/ui/theme.json`.
    pub fn path() -> Option<PathBuf> {
        if let Some(p) = std::env::var_os("UI_THEME") {
            return Some(p.into());
        }
        let base = std::env::var_os("XDG_CONFIG_HOME")
            .map(PathBuf::from)
            .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".config")))?;
        Some(base.join("ui/theme.json"))
    }

    /// Load the theme; a missing or invalid file falls back to the defaults.
    pub fn load() -> Self {
        Self::path()
            .and_then(|p| std::fs::read_to_string(p).ok())
            .and_then(|s| serde_json::from_str(&s).ok())
            .unwrap_or_default()
    }
}

/// Roles for syntax highlighting (mapped to scopes by consumers such as `pv`).
#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
pub struct SyntaxColors {
    pub comment: Hex,
    pub keyword: Hex,
    pub function: Hex,
    pub string: Hex,
    pub number: Hex,
    pub type_: Hex,
    pub constant: Hex,
    pub variable: Hex,
    pub operator: Hex,
}

impl Default for SyntaxColors {
    fn default() -> Self {
        SyntaxColors {
            comment: rgb(0x5c, 0x67, 0x73),
            keyword: rgb(0xff, 0x8f, 0x40),
            function: rgb(0xff, 0xb4, 0x54),
            string: rgb(0xaa, 0xd9, 0x4c),
            number: rgb(0xd2, 0xa6, 0xff),
            type_: rgb(0x59, 0xc2, 0xff),
            constant: rgb(0xd2, 0xa6, 0xff),
            variable: rgb(0xbf, 0xbd, 0xb6),
            operator: rgb(0xf2, 0x93, 0x6e),
        }
    }
}
