use crate::{Error, err};
use gix::bstr::ByteSlice;
use std::collections::HashMap;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    Added,
    Modified,
    Deleted,
    Renamed,
    Typechange,
    Untracked,
    Conflict,
}

/// Per-file state: `staged` is HEAD vs index, `unstaged` is index vs work tree
/// (untracked files are `unstaged = Untracked`).
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct FileStatus {
    pub staged: Option<Kind>,
    pub unstaged: Option<Kind>,
}

impl FileStatus {
    /// The single most relevant state: conflict, then unstaged, then staged.
    pub fn primary(&self) -> Option<Kind> {
        if self.unstaged == Some(Kind::Conflict) {
            return Some(Kind::Conflict);
        }
        self.unstaged.or(self.staged)
    }
}

/// Repo-wide status, keyed by repo-relative path.
#[derive(Debug, Default)]
pub struct Status {
    files: HashMap<PathBuf, FileStatus>,
}

impl Status {
    pub fn get(&self, rela: &Path) -> Option<&FileStatus> {
        self.files.get(rela)
    }

    /// Most relevant state of a folder: the first changed entry beneath it
    /// (conflicts win). `None` if nothing beneath it changed.
    pub fn dir(&self, rela: &Path) -> Option<Kind> {
        let mut found = None;
        for (p, s) in &self.files {
            if p.starts_with(rela) && p != rela {
                match s.primary() {
                    Some(Kind::Conflict) => return Some(Kind::Conflict),
                    Some(k) => found = found.or(Some(k)),
                    None => {}
                }
            }
        }
        found
    }

    pub fn iter(&self) -> impl Iterator<Item = (&Path, &FileStatus)> {
        self.files.iter().map(|(p, s)| (p.as_path(), s))
    }

    pub fn is_empty(&self) -> bool {
        self.files.is_empty()
    }

    fn entry(&mut self, path: &gix::bstr::BStr) -> &mut FileStatus {
        let p = PathBuf::from(path.to_str_lossy().into_owned());
        self.files.entry(p).or_default()
    }
}

pub(crate) fn compute(repo: &gix::Repository) -> Result<Status, Error> {
    use gix::status::index_worktree::Item as Iw;
    use gix::status::plumbing::index_as_worktree::{Change, EntryStatus};
    use gix::status::Item;

    let mut out = Status::default();
    let iter = repo
        .status(gix::progress::Discard)
        .map_err(err)?
        .untracked_files(gix::status::UntrackedFiles::Files)
        .into_iter(Vec::new())
        .map_err(err)?;

    for item in iter {
        match item.map_err(err)? {
            Item::IndexWorktree(Iw::Modification { rela_path, status, .. }) => {
                let kind = match status {
                    EntryStatus::Conflict { .. } => Kind::Conflict,
                    EntryStatus::Change(Change::Removed) => Kind::Deleted,
                    EntryStatus::Change(Change::Type { .. }) => Kind::Typechange,
                    EntryStatus::Change(_) => Kind::Modified,
                    EntryStatus::IntentToAdd => Kind::Added,
                    EntryStatus::NeedsUpdate(_) => continue,
                };
                out.entry(rela_path.as_ref()).unstaged = Some(kind);
            }
            Item::IndexWorktree(Iw::DirectoryContents { entry, .. }) => {
                if matches!(entry.status, gix::dir::entry::Status::Untracked) {
                    out.entry(entry.rela_path.as_ref()).unstaged = Some(Kind::Untracked);
                }
            }
            Item::IndexWorktree(Iw::Rewrite { dirwalk_entry, .. }) => {
                out.entry(dirwalk_entry.rela_path.as_ref()).unstaged = Some(Kind::Renamed);
            }
            Item::TreeIndex(change) => {
                use gix::diff::index::Change as C;
                let kind = match &change {
                    C::Addition { .. } => Kind::Added,
                    C::Deletion { .. } => Kind::Deleted,
                    C::Modification { .. } => Kind::Modified,
                    C::Rewrite { .. } => Kind::Renamed,
                };
                out.entry(change.location()).staged = Some(kind);
            }
        }
    }
    Ok(out)
}

impl FileStatus {
    /// One-cell sign for the file's state: unstaged and untracked first, then
    /// staged (`M` modified, `A` added, `D` deleted, `R` renamed, `?` untracked,
    /// `U` conflict, `+` staged change). Shared by every tool that draws git state.
    pub fn sign(&self) -> Option<(char, Kind)> {
        use Kind::*;
        if let Some(k) = self.unstaged {
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
        let k = self.staged?;
        let c = match k {
            Added => 'A',
            Deleted => 'D',
            Conflict => 'U',
            _ => '+',
        };
        Some((c, k))
    }
}
