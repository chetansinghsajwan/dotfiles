use crate::{Error, err};
use gix::diff::blob::{Algorithm, Diff, InternedInput};
use std::path::Path;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LineKind {
    Added,
    Modified,
    /// Lines were removed after `line`; there is no row of its own.
    Deleted,
}

/// A changed region in work-tree line numbers (1-based, inclusive).
/// For `Deleted`, `start == end` is the line *before* which lines were removed
/// (0 if removed at the very top).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct LineChange {
    pub kind: LineKind,
    pub start: u32,
    pub end: u32,
}

pub(crate) fn compute(repo: &gix::Repository, root: &Path, rela: &Path) -> Result<Vec<LineChange>, Error> {
    let after = match std::fs::read(root.join(rela)) {
        Ok(b) => b,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Vec::new(),
        Err(e) => return Err(err(e)),
    };
    // Content at HEAD; missing (new file, unborn HEAD) counts as empty.
    let before = head_blob(repo, rela).unwrap_or_default();

    let input = InternedInput::new(before.as_slice(), after.as_slice());
    let diff = Diff::compute(Algorithm::Histogram, &input);

    let mut out = Vec::new();
    for h in diff.hunks() {
        let (removed, added) = (h.before.len() as u32, h.after.len() as u32);
        if added == 0 {
            out.push(LineChange { kind: LineKind::Deleted, start: h.after.start, end: h.after.start });
        } else {
            let kind = if removed == 0 { LineKind::Added } else { LineKind::Modified };
            out.push(LineChange { kind, start: h.after.start + 1, end: h.after.end });
        }
    }
    Ok(out)
}

pub(crate) fn head_blob(repo: &gix::Repository, rela: &Path) -> Option<Vec<u8>> {
    let tree = repo.head_commit().ok()?.tree().ok()?;
    let entry = tree.lookup_entry_by_path(rela).ok()??;
    Some(entry.object().ok()?.detach().data)
}

