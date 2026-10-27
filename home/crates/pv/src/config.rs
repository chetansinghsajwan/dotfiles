//! `$XDG_CONFIG_HOME/pv/config.toml` (else `~/.config/pv/config.toml`).

use serde::Deserialize;
use std::path::PathBuf;

#[derive(Debug, Deserialize)]
#[serde(default)]
pub struct Config {
    /// Git status colors and signs. On by default; `--no-git` also disables it.
    pub git: bool,
}

impl Default for Config {
    fn default() -> Self {
        Config { git: true }
    }
}

impl Config {
    pub fn path() -> Option<PathBuf> {
        let base = std::env::var_os("XDG_CONFIG_HOME")
            .map(PathBuf::from)
            .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".config")))?;
        Some(base.join("pv/config.toml"))
    }

    /// Missing or invalid file falls back to the defaults.
    pub fn load() -> Self {
        Self::path()
            .and_then(|p| std::fs::read_to_string(p).ok())
            .and_then(|s| toml::from_str(&s).ok())
            .unwrap_or_default()
    }
}
