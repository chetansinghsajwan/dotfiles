//! Git decoration shared by the text and directory renderers.

use ratatui::style::Color;
use std::path::Path;
use ui::Theme;

pub use git_core::{Kind, LineKind, PatchKind, Repo, Status};

pub fn kind_color(theme: &Theme, kind: Kind) -> Color {
    let g = &theme.colors.git;
    match kind {
        Kind::Added => g.added,
        Kind::Modified | Kind::Typechange => g.modified,
        Kind::Deleted => g.deleted,
        Kind::Renamed => g.renamed,
        Kind::Untracked => g.untracked,
        Kind::Conflict => g.conflict,
    }
    .into()
}

pub fn line_color(theme: &Theme, kind: LineKind) -> Color {
    let g = &theme.colors.git;
    match kind {
        LineKind::Added => g.added,
        LineKind::Modified => g.modified,
        LineKind::Deleted => g.deleted,
    }
    .into()
}

/// One-cell sign for a file's state: unstaged and untracked first, then staged.
pub fn sign(status: &git_core::FileStatus) -> Option<(char, Kind)> {
    use Kind::*;
    if let Some(k) = status.unstaged {
        let c = match k {
            Conflict => 'U',
            Untracked => '?',
            Deleted => 'D',
            Added => 'A',
            Renamed => 'R',
            Modified | Typechange => 'M',
        };
        return Some((c, k));
    }
    let k = status.staged?;
    let c = match k {
        Added => 'A',
        Deleted => 'D',
        Conflict => 'U',
        _ => '+',
    };
    Some((c, k))
}

/// The repo containing `path` and its status, computed once.
pub fn load(path: &Path) -> Option<(Repo, Status)> {
    let repo = Repo::discover(path)?;
    let status = repo.status().ok()?;
    Some((repo, status))
}

/// Row tint: the git color at 18% over the background.
pub fn tint(theme: &Theme, color: Color) -> Color {
    ui::mix(color, theme.colors.bg.into(), 18)
}
