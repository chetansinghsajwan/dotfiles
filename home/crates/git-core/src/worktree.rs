//! Working-tree changes and the operations that change them (stage, unstage,
//! discard, commit). Reading goes through `gix`; writing runs the `git` command
//! line, as lazygit does, so hooks, signing and every edge case behave exactly as
//! the user's git does.

use crate::history::{FilePatch, hunks};
use crate::lines::head_blob;
use crate::{Error, Kind, Repo, err};
use gix::bstr::ByteSlice;
use std::path::{Path, PathBuf};
use std::process::Command;

/// Which comparison a file diff shows.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Side {
    /// `HEAD` against the index: what the next commit contains.
    Staged,
    /// The index against the work tree: what is not staged yet (an untracked
    /// file counts as all added).
    Unstaged,
}

impl Repo {
    fn index_blob(&self, rela: &Path) -> Option<Vec<u8>> {
        let index = self.repo.index_or_empty().ok()?;
        let entry = index.entry_by_path(rela.to_str()?.into())?;
        Some(self.repo.find_blob(entry.id).ok()?.detach().data)
    }

    /// The diff of one file (path relative to the work tree) on `side`.
    pub fn diff_file(&self, rela: &Path, side: Side) -> Result<FilePatch, Error> {
        let (before, after, kind) = match side {
            Side::Staged => {
                let before = head_blob(&self.repo, rela);
                let after = self.index_blob(rela);
                let kind = match (&before, &after) {
                    (None, _) => Kind::Added,
                    (_, None) => Kind::Deleted,
                    _ => Kind::Modified,
                };
                (before.unwrap_or_default(), after.unwrap_or_default(), kind)
            }
            Side::Unstaged => {
                let before = self.index_blob(rela);
                let after = std::fs::read(self.root.join(rela)).ok();
                let kind = match (&before, &after) {
                    (None, _) => Kind::Untracked,
                    (_, None) => Kind::Deleted,
                    _ => Kind::Modified,
                };
                (before.unwrap_or_default(), after.unwrap_or_default(), kind)
            }
        };
        let binary = before.contains(&0) || after.contains(&0);
        Ok(FilePatch { path: rela.to_string_lossy().into_owned(), kind, binary, hunks: if binary { Vec::new() } else { hunks(&before, &after) } })
    }

    /// The checked-out branch, or `None` on a detached HEAD.
    pub fn branch(&self) -> Option<String> {
        let name = self.repo.head_name().ok()??;
        Some(name.shorten().to_str_lossy().into_owned())
    }

    fn git(&self, args: &[&str], paths: &[PathBuf]) -> Result<String, Error> {
        let mut cmd = Command::new("git");
        cmd.current_dir(&self.root).args(["--no-pager", "-c", "core.quotepath=off"]).args(args);
        if !paths.is_empty() {
            cmd.arg("--").args(paths);
        }
        let out = cmd.env("GIT_TERMINAL_PROMPT", "0").env("GIT_EDITOR", "true").output().map_err(err)?;
        if out.status.success() {
            return Ok(String::from_utf8_lossy(&out.stdout).into_owned());
        }
        let msg = String::from_utf8_lossy(&out.stderr).trim().to_string();
        let msg = if msg.is_empty() { String::from_utf8_lossy(&out.stdout).trim().to_string() } else { msg };
        Err(Error(msg.lines().last().unwrap_or("git failed").to_string()))
    }

    fn has_head(&self) -> bool {
        self.repo.head_commit().is_ok()
    }

    /// Stage changes (new, modified and deleted files) for `paths`.
    pub fn stage(&self, paths: &[PathBuf]) -> Result<(), Error> {
        self.git(&["add", "-A"], paths).map(|_| ())
    }

    /// Stage everything.
    pub fn stage_all(&self) -> Result<(), Error> {
        self.git(&["add", "-A"], &[]).map(|_| ())
    }

    /// Unstage `paths` (keeps the work tree as is).
    pub fn unstage(&self, paths: &[PathBuf]) -> Result<(), Error> {
        if self.has_head() {
            self.git(&["restore", "--staged"], paths).map(|_| ())
        } else {
            // No commit yet: unstaging means removing the files from the index.
            self.git(&["rm", "-r", "--cached", "-q"], paths).map(|_| ())
        }
    }

    pub fn unstage_all(&self) -> Result<(), Error> {
        if self.has_head() { self.git(&["reset", "-q"], &[]).map(|_| ()) } else { self.git(&["rm", "-r", "--cached", "-q", "."], &[]).map(|_| ()) }
    }

    /// Throw away work-tree changes: tracked files are restored from the index,
    /// untracked files are deleted. Not recoverable.
    pub fn discard(&self, rela: &Path, untracked: bool) -> Result<(), Error> {
        if untracked {
            let path = self.root.join(rela);
            let meta = path.symlink_metadata().map_err(err)?;
            return if meta.is_dir() { std::fs::remove_dir_all(path) } else { std::fs::remove_file(path) }.map_err(err);
        }
        self.git(&["restore"], &[rela.to_path_buf()]).map(|_| ())
    }

    /// Commit what is staged. Returns `short-hash subject`.
    pub fn create_commit(&self, message: &str) -> Result<String, Error> {
        if message.trim().is_empty() {
            return Err(Error("empty commit message".into()));
        }
        self.git(&["commit", "-q", "-m", message], &[])?;
        let head = self.repo.head_commit().map_err(err)?;
        let id = head.id.to_string();
        Ok(format!("{} {}", &id[..id.len().min(8)], message.lines().next().unwrap_or("")))
    }
}
