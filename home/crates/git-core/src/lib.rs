//! `git-core`: the one place git logic lives. Repo discovery, per-file status
//! and per-line changes, on `gix`. Used by `pv`, `pick`, the files panel and
//! `git-panel` so none of them talk to git themselves.

mod lines;
mod status;

pub use lines::{LineChange, LineKind};
pub use status::{FileStatus, Kind, Status};

use std::path::{Path, PathBuf};

#[derive(Debug)]
pub struct Error(pub String);

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.0)
    }
}

impl std::error::Error for Error {}

fn err(e: impl std::fmt::Display) -> Error {
    Error(e.to_string())
}

/// A discovered repository with a work tree.
pub struct Repo {
    repo: gix::Repository,
    root: PathBuf,
}

impl Repo {
    /// Find the repository containing `path`. `None` if there is none, or it
    /// is bare.
    pub fn discover(path: &Path) -> Option<Repo> {
        let dir = if path.is_dir() { path } else { path.parent()? };
        let repo = gix::discover(dir).ok()?;
        let root = repo.workdir()?.canonicalize().ok()?;
        Some(Repo { repo, root })
    }

    /// The work tree root (canonical).
    pub fn root(&self) -> &Path {
        &self.root
    }

    /// Repo-relative path for `path`, if it lies inside the work tree.
    pub fn relative(&self, path: &Path) -> Option<PathBuf> {
        let abs = if path.is_absolute() { path.to_path_buf() } else { std::env::current_dir().ok()?.join(path) };
        // Canonicalize the parent so a missing (deleted) file still resolves.
        let canon = match abs.canonicalize() {
            Ok(p) => p,
            Err(_) => abs.parent()?.canonicalize().ok()?.join(abs.file_name()?),
        };
        canon.strip_prefix(&self.root).ok().map(Path::to_path_buf)
    }

    /// Status of every changed path in the repo. Compute once and cache.
    pub fn status(&self) -> Result<Status, Error> {
        status::compute(&self.repo)
    }

    /// Changed lines of `path` in the work tree compared to `HEAD`.
    pub fn line_changes(&self, path: &Path) -> Result<Vec<LineChange>, Error> {
        let rela = self.relative(path).ok_or_else(|| err("path is outside the work tree"))?;
        lines::compute(&self.repo, &self.root, &rela)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::process::Command;

    fn git(dir: &Path, args: &[&str]) {
        let ok = Command::new("git")
            .args(["-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false"])
            .args(args)
            .current_dir(dir)
            .env("GIT_CONFIG_GLOBAL", "/dev/null")
            .env("GIT_CONFIG_SYSTEM", "/dev/null")
            .status()
            .unwrap()
            .success();
        assert!(ok, "git {args:?} failed");
    }

    fn repo(name: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("git-core-test-{}-{name}", std::process::id()));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(&d).unwrap();
        git(&d, &["init", "-q", "-b", "main"]);
        fs::write(d.join("a.txt"), "1\n2\n3\n4\n5\n").unwrap();
        fs::write(d.join("b.txt"), "b\n").unwrap();
        fs::create_dir(d.join("sub")).unwrap();
        fs::write(d.join("sub/c.txt"), "c\n").unwrap();
        git(&d, &["add", "."]);
        git(&d, &["commit", "-q", "-m", "init"]);
        d.canonicalize().unwrap()
    }

    #[test]
    fn not_a_repo() {
        let d = std::env::temp_dir().join(format!("git-core-none-{}", std::process::id()));
        fs::create_dir_all(&d).unwrap();
        assert!(Repo::discover(&d).is_none());
    }

    #[test]
    fn status_staged_unstaged_untracked() {
        let d = repo("status");
        fs::write(d.join("a.txt"), "1\nX\n3\n4\n5\n").unwrap(); // modified, unstaged
        fs::write(d.join("b.txt"), "bb\n").unwrap();
        git(&d, &["add", "b.txt"]); // modified, staged
        fs::write(d.join("new.txt"), "n\n").unwrap(); // untracked
        fs::write(d.join("sub/d.txt"), "d\n").unwrap();
        git(&d, &["add", "sub/d.txt"]); // added, staged
        fs::remove_file(d.join("sub/c.txt")).unwrap(); // deleted, unstaged

        let r = Repo::discover(&d).unwrap();
        let s = r.status().unwrap();
        assert_eq!(s.get(Path::new("a.txt")).unwrap().unstaged, Some(Kind::Modified));
        assert_eq!(s.get(Path::new("b.txt")).unwrap().staged, Some(Kind::Modified));
        assert_eq!(s.get(Path::new("new.txt")).unwrap().unstaged, Some(Kind::Untracked));
        assert_eq!(s.get(Path::new("sub/d.txt")).unwrap().staged, Some(Kind::Added));
        assert_eq!(s.get(Path::new("sub/c.txt")).unwrap().unstaged, Some(Kind::Deleted));
        assert!(s.dir(Path::new("sub")).is_some());
        assert!(s.get(Path::new("nothing")).is_none());
    }

    #[test]
    fn clean_repo_is_empty() {
        let d = repo("clean");
        assert!(Repo::discover(&d).unwrap().status().unwrap().is_empty());
    }

    #[test]
    fn conflict_is_reported() {
        let d = repo("conflict");
        git(&d, &["checkout", "-q", "-b", "other"]);
        fs::write(d.join("b.txt"), "other\n").unwrap();
        git(&d, &["commit", "-qam", "other"]);
        git(&d, &["checkout", "-q", "main"]);
        fs::write(d.join("b.txt"), "main\n").unwrap();
        git(&d, &["commit", "-qam", "main"]);
        let _ = Command::new("git")
            .args(["-c", "user.name=t", "-c", "user.email=t@t", "merge", "other"])
            .current_dir(&d)
            .env("GIT_CONFIG_GLOBAL", "/dev/null")
            .output();
        let s = Repo::discover(&d).unwrap().status().unwrap();
        assert_eq!(s.get(Path::new("b.txt")).unwrap().primary(), Some(Kind::Conflict));
    }

    #[test]
    fn line_changes_vs_head() {
        let d = repo("lines");
        // modify line 2, add a line at the end, delete line 4
        fs::write(d.join("a.txt"), "1\nX\n3\n5\nnew\n").unwrap();
        let r = Repo::discover(&d).unwrap();
        let c = r.line_changes(&d.join("a.txt")).unwrap();
        assert!(c.contains(&LineChange { kind: LineKind::Modified, start: 2, end: 2 }), "{c:?}");
        assert!(c.iter().any(|x| x.kind == LineKind::Added && x.start == 5), "{c:?}");
        assert!(c.iter().any(|x| x.kind == LineKind::Deleted), "{c:?}");
    }

    #[test]
    fn untracked_file_is_all_added_and_clean_file_has_none() {
        let d = repo("untracked");
        fs::write(d.join("n.txt"), "x\ny\n").unwrap();
        let r = Repo::discover(&d).unwrap();
        assert_eq!(r.line_changes(&d.join("n.txt")).unwrap(), vec![LineChange { kind: LineKind::Added, start: 1, end: 2 }]);
        assert!(r.line_changes(&d.join("b.txt")).unwrap().is_empty());
    }
}
