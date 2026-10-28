//! Candidate sources. Each pushes into a `nucleo` injector from its own thread,
//! so the UI stays responsive while candidates stream in.

use crate::candidate::Candidate;
use nucleo::Injector;
use std::io::BufRead;
use std::path::{Path, PathBuf};
use std::thread;

/// How input lines become candidates.
#[derive(Debug, Clone, Default)]
pub struct LineFormat {
    /// Show only this field (1-based) and match against it; the whole line is
    /// still what accepting prints and what a preview command receives.
    pub with_nth: Option<usize>,
    /// Field separator for `with_nth` (default: whitespace).
    pub delimiter: Option<String>,
}

fn candidate(line: String, fmt: &LineFormat) -> Candidate {
    let Some(n) = fmt.with_nth.filter(|&n| n >= 1) else { return Candidate::plain(line) };
    let field = match fmt.delimiter.as_deref().filter(|d| !d.is_empty()) {
        Some(d) => line.split(d).nth(n - 1),
        None => line.split_whitespace().nth(n - 1),
    }
    .unwrap_or("")
    .to_string();
    Candidate::with_raw(field, line)
}

/// Lines from a reader (e.g. stdin), one candidate per line.
pub fn spawn_lines(inj: Injector<Candidate>, reader: impl BufRead + Send + 'static) {
    spawn_lines_with(inj, reader, LineFormat::default());
}

/// Like `spawn_lines`, with a field shown instead of the whole line.
pub fn spawn_lines_with(inj: Injector<Candidate>, reader: impl BufRead + Send + 'static, fmt: LineFormat) {
    thread::spawn(move || {
        for line in reader.lines().map_while(Result::ok) {
            if !line.is_empty() {
                inj.push(candidate(line, &fmt), |c, cols| cols[0] = c.display.as_str().into());
            }
        }
    });
}

/// Files under `root` (respects .gitignore), as paths relative to `root`. With
/// `dirs`, folders are included too, marked with a trailing `/`.
pub fn spawn_files(inj: Injector<Candidate>, root: PathBuf, dirs: bool) {
    walk(inj, root, true, dirs);
}

/// Only the folders under `root`, marked with a trailing `/`.
pub fn spawn_dirs(inj: Injector<Candidate>, root: PathBuf) {
    walk(inj, root, false, true);
}

fn walk(inj: Injector<Candidate>, root: PathBuf, files: bool, dirs: bool) {
    thread::spawn(move || {
        for entry in ignore::WalkBuilder::new(&root).hidden(false).filter_entry(|e| e.file_name() != ".git").build().flatten() {
            let Some(ft) = entry.file_type() else { continue };
            if entry.depth() == 0 || !((files && ft.is_file()) || (dirs && ft.is_dir())) {
                continue;
            }
            let rela: &Path = entry.path().strip_prefix(&root).unwrap_or(entry.path());
            if let Some(s) = rela.to_str() {
                let mut s = s.to_string();
                if ft.is_dir() {
                    s.push('/');
                }
                inj.push(Candidate::plain(s), |c, cols| cols[0] = c.display.as_str().into());
            }
        }
    });
}

/// Which git objects to list.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GitSource {
    /// Branches, remote branches and tags.
    Refs,
    /// Commits reachable from HEAD.
    Commits,
    Stashes,
}

/// Most commits listed; keeps huge histories responsive.
const MAX_COMMITS: usize = 5000;

/// Refs, commits or stashes of the repository containing `root`.
pub fn spawn_git(inj: Injector<Candidate>, root: PathBuf, what: GitSource) {
    use crate::candidate::{GitItem, GitKind};
    use git_core::{RefKind, Repo};
    thread::spawn(move || {
        // `Repo` is not `Send`, so it is opened on this thread.
        let Some(repo) = Repo::discover(&root) else { return };
        let push = |c: Candidate| {
            inj.push(c, |c, cols| cols[0] = c.display.as_str().into());
        };
        match what {
            GitSource::Refs => {
                for r in repo.refs().unwrap_or_default() {
                    let kind = match r.kind {
                        RefKind::Branch => GitKind::Branch,
                        RefKind::Remote => GitKind::Remote,
                        RefKind::Tag => GitKind::Tag,
                    };
                    push(Candidate::git_item(GitItem { kind, name: r.name, oid: r.oid, subject: r.subject, time: r.time, is_head: r.is_head }));
                }
            }
            GitSource::Commits => {
                for c in repo.commits(MAX_COMMITS).unwrap_or_default() {
                    push(Candidate::git_item(GitItem { kind: GitKind::Commit, name: c.short, oid: c.oid, subject: c.subject, time: c.time, is_head: false }));
                }
            }
            GitSource::Stashes => {
                for s in repo.stashes().unwrap_or_default() {
                    push(Candidate::git_item(GitItem {
                        kind: GitKind::Stash,
                        name: format!("stash@{{{}}}", s.index),
                        oid: s.oid,
                        subject: s.message,
                        time: s.time,
                        is_head: false,
                    }));
                }
            }
        }
    });
}

/// Push ready-made candidates (e.g. an editor's open buffers) in order.
pub fn push_candidates(inj: &Injector<Candidate>, items: Vec<Candidate>) {
    for c in items {
        inj.push(c, |c, cols| cols[0] = c.display.as_str().into());
    }
}
