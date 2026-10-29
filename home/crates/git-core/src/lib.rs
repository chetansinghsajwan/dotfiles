//! `git-core`: the one place git logic lives. Repo discovery, per-file status
//! and per-line changes, on `gix`. Used by `pv`, `pick`, the files panel and
//! `git-panel` so none of them talk to git themselves.

mod history;
mod lines;
mod status;
mod worktree;

pub use history::{CommitInfo, FileChange, FilePatch, Hunk, PatchKind, PatchLine, RefInfo, RefKind, StashInfo};
pub use lines::{LineChange, LineKind};
pub use status::{FileStatus, Kind, Status};
pub use worktree::Side;

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

    /// Branches, remote branches and tags: the checked-out branch first, then
    /// local branches, remotes and tags, newest first.
    pub fn refs(&self) -> Result<Vec<RefInfo>, Error> {
        history::refs(&self.repo)
    }

    /// Up to `limit` commits reachable from `HEAD`, newest first.
    pub fn commits(&self, limit: usize) -> Result<Vec<CommitInfo>, Error> {
        history::commits(&self.repo, limit)
    }

    /// Stash entries, newest (`stash@{0}`) first.
    pub fn stashes(&self) -> Result<Vec<StashInfo>, Error> {
        history::stashes(&self.repo)
    }

    /// One commit by hash, ref name or any rev-spec.
    pub fn commit(&self, rev: &str) -> Result<CommitInfo, Error> {
        history::commit(&self.repo, rev)
    }

    /// Files changed by `rev` against its first parent, with line counts.
    pub fn changes(&self, rev: &str) -> Result<Vec<FileChange>, Error> {
        history::changes(&self.repo, rev)
    }

    /// The patch of `rev` against its first parent: per file, hunks with 3
    /// lines of context. Binary files have no hunks.
    pub fn patch(&self, rev: &str) -> Result<Vec<FilePatch>, Error> {
        history::patch(&self.repo, rev)
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

    /// Commits made through `Repo::create_commit` use the ambient git identity,
    /// which a clean build sandbox does not have.
    fn identity() {
        static ONCE: std::sync::Once = std::sync::Once::new();
        ONCE.call_once(|| {
            for (k, v) in [("GIT_AUTHOR_NAME", "t"), ("GIT_AUTHOR_EMAIL", "t@t"), ("GIT_COMMITTER_NAME", "t"), ("GIT_COMMITTER_EMAIL", "t@t")] {
                // SAFETY: set once, before any test spawns git, to constants.
                unsafe { std::env::set_var(k, v) };
            }
        });
    }

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
        identity();
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
    fn refs_commits_and_changes() {
        let d = repo("history");
        git(&d, &["tag", "v1"]);
        git(&d, &["tag", "-a", "v1-annotated", "-m", "release"]);
        git(&d, &["checkout", "-q", "-b", "feature"]);
        fs::write(d.join("a.txt"), "1\n2\nX\n4\n5\nmore\n").unwrap(); // +2 -1 vs "1..5"
        fs::write(d.join("new.txt"), "n\nn\n").unwrap();
        git(&d, &["rm", "-q", "b.txt"]);
        git(&d, &["add", "."]);
        git(&d, &["commit", "-q", "-m", "second\n\nlonger body"]);
        let r = Repo::discover(&d).unwrap();

        let refs = r.refs().unwrap();
        let names: Vec<(&str, RefKind, bool)> = refs.iter().map(|x| (x.name.as_str(), x.kind, x.is_head)).collect();
        assert_eq!(names[0], ("feature", RefKind::Branch, true), "{names:?}");
        assert!(names.contains(&("main", RefKind::Branch, false)));
        assert!(names.contains(&("v1", RefKind::Tag, false)) && names.contains(&("v1-annotated", RefKind::Tag, false)));
        // Annotated tags peel to the commit.
        let init = r.commit("main").unwrap();
        assert_eq!(refs.iter().find(|x| x.name == "v1-annotated").unwrap().oid, init.oid);
        assert_eq!(refs[0].subject, "second");

        let log = r.commits(10).unwrap();
        assert_eq!(log.len(), 2);
        assert_eq!(log[0].subject, "second");
        assert_eq!(log[0].message, "second\n\nlonger body");
        assert_eq!((log[0].author.as_str(), log[0].email.as_str()), ("t", "t@t"));
        assert_eq!(log[0].parents, vec![log[1].oid.clone()]);
        assert_eq!(r.commits(1).unwrap().len(), 1);

        let ch = r.changes("HEAD").unwrap();
        let get = |p: &str| ch.iter().find(|c| c.path == p).unwrap_or_else(|| panic!("{p} in {ch:?}"));
        assert_eq!((get("a.txt").kind, get("a.txt").added, get("a.txt").removed), (Kind::Modified, 2, 1));
        assert_eq!((get("new.txt").kind, get("new.txt").added), (Kind::Added, 2));
        assert_eq!(get("b.txt").kind, Kind::Deleted);
        // The root commit is diffed against the empty tree.
        assert!(r.changes(&init.oid).unwrap().iter().all(|c| c.kind == Kind::Added));
    }

    #[test]
    fn patch_has_hunks_with_context() {
        let d = repo("patch");
        let base: String = (1..=20).map(|n| format!("{n}\n")).collect();
        fs::write(d.join("long.txt"), &base).unwrap();
        git(&d, &["add", "."]);
        git(&d, &["commit", "-q", "-m", "base"]);
        // Change line 5 and line 18 (far apart: two hunks), add a file, delete one.
        let changed: String = (1..=20).map(|n| if n == 5 { "FIVE\n".into() } else if n == 18 { "EIGHTEEN\n".into() } else { format!("{n}\n") }).collect();
        fs::write(d.join("long.txt"), changed).unwrap();
        fs::write(d.join("new.txt"), "x\ny\n").unwrap();
        git(&d, &["rm", "-q", "b.txt"]);
        git(&d, &["add", "."]);
        git(&d, &["commit", "-q", "-m", "change"]);

        let r = Repo::discover(&d).unwrap();
        let p = r.patch("HEAD").unwrap();
        let file = |n: &str| p.iter().find(|f| f.path == n).unwrap();

        let long = file("long.txt");
        assert_eq!(long.hunks.len(), 2, "{long:?}");
        let h = &long.hunks[0];
        assert_eq!((h.old_start, h.old_len, h.new_start, h.new_len), (2, 7, 2, 7));
        let shape: Vec<(PatchKind, &str)> = h.lines.iter().map(|l| (l.kind, l.text.as_str())).collect();
        assert_eq!(
            shape,
            vec![
                (PatchKind::Context, "2"),
                (PatchKind::Context, "3"),
                (PatchKind::Context, "4"),
                (PatchKind::Removed, "5"),
                (PatchKind::Added, "FIVE"),
                (PatchKind::Context, "6"),
                (PatchKind::Context, "7"),
                (PatchKind::Context, "8"),
            ]
        );
        assert_eq!((long.hunks[1].old_start, long.hunks[1].old_len), (15, 6)); // 15..20, ends at EOF

        let new = file("new.txt");
        assert_eq!(new.hunks.len(), 1);
        assert_eq!((new.hunks[0].old_start, new.hunks[0].old_len, new.hunks[0].new_start, new.hunks[0].new_len), (0, 0, 1, 2));
        assert!(new.hunks[0].lines.iter().all(|l| l.kind == PatchKind::Added));
        let gone = file("b.txt");
        assert_eq!((gone.kind, gone.hunks[0].new_len), (Kind::Deleted, 0));

        // Counts of every hunk are consistent with its lines.
        for f in &p {
            for h in &f.hunks {
                let old = h.lines.iter().filter(|l| l.kind != PatchKind::Added).count() as u32;
                let new = h.lines.iter().filter(|l| l.kind != PatchKind::Removed).count() as u32;
                assert_eq!((old, new), (h.old_len, h.new_len));
            }
        }
    }

    #[test]
    fn nearby_changes_merge_into_one_hunk_and_binary_has_none() {
        let d = repo("merge");
        let base: String = (1..=12).map(|n| format!("{n}\n")).collect();
        fs::write(d.join("m.txt"), &base).unwrap();
        fs::write(d.join("bin.dat"), [0u8, 1, 2]).unwrap();
        git(&d, &["add", "."]);
        git(&d, &["commit", "-q", "-m", "base"]);
        let changed: String = (1..=12).map(|n| if n == 3 || n == 8 { "Z\n".into() } else { format!("{n}\n") }).collect();
        fs::write(d.join("m.txt"), changed).unwrap();
        fs::write(d.join("bin.dat"), [0u8, 9, 9, 9]).unwrap();
        git(&d, &["commit", "-qam", "edit"]);
        let p = Repo::discover(&d).unwrap().patch("HEAD").unwrap();
        // Lines 3 and 8 are 4 apart (<= 6): one hunk.
        assert_eq!(p.iter().find(|f| f.path == "m.txt").unwrap().hunks.len(), 1);
        let bin = p.iter().find(|f| f.path == "bin.dat").unwrap();
        assert!(bin.binary && bin.hunks.is_empty());
    }

    #[test]
    fn diff_file_shows_staged_and_unstaged_sides() {
        let d = repo("diffside");
        fs::write(d.join("a.txt"), "1\n2\nTHREE\n4\n5\n").unwrap();
        git(&d, &["add", "a.txt"]); // staged: line 3 changed
        fs::write(d.join("a.txt"), "1\n2\nTHREE\n4\n5\nsix\n").unwrap(); // unstaged: line 6 added
        fs::write(d.join("new.txt"), "n1\nn2\n").unwrap(); // untracked
        let r = Repo::discover(&d).unwrap();

        let staged = r.diff_file(Path::new("a.txt"), Side::Staged).unwrap();
        assert_eq!(staged.kind, Kind::Modified);
        let adds: Vec<&str> = staged.hunks[0].lines.iter().filter(|l| l.kind == PatchKind::Added).map(|l| l.text.as_str()).collect();
        assert_eq!(adds, vec!["THREE"]);

        let unstaged = r.diff_file(Path::new("a.txt"), Side::Unstaged).unwrap();
        let adds: Vec<&str> = unstaged.hunks[0].lines.iter().filter(|l| l.kind == PatchKind::Added).map(|l| l.text.as_str()).collect();
        assert_eq!(adds, vec!["six"]);

        let untracked = r.diff_file(Path::new("new.txt"), Side::Unstaged).unwrap();
        assert_eq!(untracked.kind, Kind::Untracked);
        assert_eq!(untracked.hunks[0].lines.len(), 2);
        // A new file staged shows as added; unborn-HEAD style "no staged change" is empty.
        git(&d, &["add", "new.txt"]);
        assert_eq!(r.diff_file(Path::new("new.txt"), Side::Staged).unwrap().kind, Kind::Added);
        assert!(r.diff_file(Path::new("b.txt"), Side::Staged).unwrap().hunks.is_empty());
        assert_eq!(r.branch().as_deref(), Some("main"));
    }

    #[test]
    fn stage_unstage_discard_and_commit() {
        let d = repo("writes");
        fs::write(d.join("a.txt"), "changed\n").unwrap();
        fs::write(d.join("new.txt"), "n\n").unwrap();
        fs::remove_file(d.join("b.txt")).unwrap();
        let r = Repo::discover(&d).unwrap();
        let kind = |r: &Repo, p: &str| r.status().unwrap().get(Path::new(p)).copied();

        r.stage(&[PathBuf::from("a.txt"), PathBuf::from("new.txt"), PathBuf::from("b.txt")]).unwrap();
        assert_eq!(kind(&r, "a.txt").unwrap().staged, Some(Kind::Modified));
        assert_eq!(kind(&r, "new.txt").unwrap().staged, Some(Kind::Added));
        assert_eq!(kind(&r, "b.txt").unwrap().staged, Some(Kind::Deleted), "deletions stage too");

        r.unstage(&[PathBuf::from("new.txt")]).unwrap();
        assert_eq!(kind(&r, "new.txt").unwrap().unstaged, Some(Kind::Untracked));
        assert!(kind(&r, "new.txt").unwrap().staged.is_none());

        // Discard restores a tracked file; an untracked one is deleted.
        fs::write(d.join("a.txt"), "scribble\n").unwrap();
        r.discard(Path::new("a.txt"), false).unwrap();
        assert_eq!(fs::read_to_string(d.join("a.txt")).unwrap(), "changed\n"); // back to the staged content
        r.discard(Path::new("new.txt"), true).unwrap();
        assert!(!d.join("new.txt").exists());

        assert!(r.create_commit("  ").is_err(), "empty message");
        let summary = r.create_commit("second\n\nbody").unwrap();
        assert!(summary.ends_with(" second"), "{summary}");
        assert!(r.status().unwrap().is_empty());
        assert_eq!(r.commits(3).unwrap()[0].subject, "second");
        // Nothing staged: git refuses and the reason comes back.
        assert!(r.create_commit("again").is_err());

        r.stage_all().unwrap();
        r.unstage_all().unwrap();
        assert!(r.status().unwrap().is_empty());
    }

    #[test]
    fn unstage_works_before_the_first_commit() {
        let d = std::env::temp_dir().join(format!("git-core-test-{}-unborn2", std::process::id()));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(&d).unwrap();
        git(&d, &["init", "-q", "-b", "main"]);
        fs::write(d.join("f.txt"), "x\n").unwrap();
        let r = Repo::discover(&d).unwrap();
        r.stage(&[PathBuf::from("f.txt")]).unwrap();
        assert_eq!(r.status().unwrap().get(Path::new("f.txt")).unwrap().staged, Some(Kind::Added));
        r.unstage(&[PathBuf::from("f.txt")]).unwrap();
        assert!(r.status().unwrap().get(Path::new("f.txt")).unwrap().staged.is_none());
        assert!(r.create_commit("first").is_err(), "nothing staged");
    }

    #[test]
    fn stashes_and_unborn_head() {
        let d = repo("stash");
        fs::write(d.join("a.txt"), "changed\n").unwrap();
        git(&d, &["stash", "push", "-q", "-m", "wip one"]);
        fs::write(d.join("a.txt"), "changed again\n").unwrap();
        git(&d, &["stash", "push", "-q", "-m", "wip two"]);
        let r = Repo::discover(&d).unwrap();
        let s = r.stashes().unwrap();
        assert_eq!(s.len(), 2);
        assert_eq!((s[0].index, s[1].index), (0, 1));
        assert!(s[0].message.contains("wip two") && s[1].message.contains("wip one"), "{s:?}");
        assert!(r.commit(&s[0].oid).is_ok());

        let e = std::env::temp_dir().join(format!("git-core-test-{}-unborn", std::process::id()));
        let _ = fs::remove_dir_all(&e);
        fs::create_dir_all(&e).unwrap();
        git(&e, &["init", "-q", "-b", "main"]);
        let r = Repo::discover(&e).unwrap();
        assert!(r.commits(5).unwrap().is_empty() && r.refs().unwrap().is_empty() && r.stashes().unwrap().is_empty());
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
