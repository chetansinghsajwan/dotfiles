//! Refs, commits, stashes and per-commit changes (read-only), for pickers and
//! the git panel.

use crate::status::Kind;
use crate::{Error, err};
use gix::bstr::ByteSlice;
use gix::diff::blob::{Algorithm, Diff, InternedInput};
use gix::object::tree::diff::ChangeDetached as Change;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RefKind {
    Branch,
    Remote,
    Tag,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RefInfo {
    /// Short name: `main`, `origin/main`, `v1.0`.
    pub name: String,
    pub kind: RefKind,
    /// Commit the ref points at (tags are peeled).
    pub oid: String,
    /// The checked-out branch.
    pub is_head: bool,
    pub subject: String,
    /// Commit time, seconds since the epoch.
    pub time: i64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CommitInfo {
    pub oid: String,
    pub short: String,
    pub subject: String,
    /// Full message, without the trailing newline.
    pub message: String,
    pub author: String,
    pub email: String,
    pub time: i64,
    pub parents: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StashInfo {
    /// `stash@{index}`, 0 is the newest.
    pub index: usize,
    pub oid: String,
    pub message: String,
    pub time: i64,
}

/// One file changed by a commit, against its first parent (or the empty tree).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FileChange {
    pub path: String,
    pub kind: Kind,
    pub added: u32,
    pub removed: u32,
    pub binary: bool,
}

pub(crate) fn commit_info(commit: &gix::Commit<'_>) -> Result<CommitInfo, Error> {
    let msg = commit.message_raw_sloppy().to_str_lossy().trim_end().to_string();
    let author = commit.author().map_err(err)?;
    let oid = commit.id.to_string();
    Ok(CommitInfo {
        short: oid[..oid.len().min(8)].to_string(),
        subject: msg.lines().next().unwrap_or("").to_string(),
        message: msg,
        author: author.name.to_str_lossy().into_owned(),
        email: author.email.to_str_lossy().into_owned(),
        time: author.time().map(|t| t.seconds).unwrap_or(0),
        parents: commit.parent_ids().map(|p| p.to_string()).collect(),
        oid,
    })
}

pub(crate) fn refs(repo: &gix::Repository) -> Result<Vec<RefInfo>, Error> {
    use gix::reference::Category;
    let head = repo.head_name().ok().flatten().map(|n| n.as_bstr().to_string());
    let mut out = Vec::new();
    let platform = repo.references().map_err(err)?;
    for r in platform.all().map_err(err)?.flatten() {
        let (kind, short) = match r.name().category_and_short_name() {
            Some((Category::LocalBranch, s)) => (RefKind::Branch, s.to_str_lossy().into_owned()),
            Some((Category::RemoteBranch, s)) => (RefKind::Remote, s.to_str_lossy().into_owned()),
            Some((Category::Tag, s)) => (RefKind::Tag, s.to_str_lossy().into_owned()),
            _ => continue,
        };
        if kind == RefKind::Remote && short.ends_with("/HEAD") {
            continue;
        }
        let mut r = r;
        let Ok(id) = r.peel_to_id() else { continue };
        let Ok(commit) = repo.find_commit(id) else { continue };
        let info = commit_info(&commit)?;
        out.push(RefInfo {
            is_head: head.as_deref() == Some(r.name().as_bstr().to_str_lossy().as_ref()),
            name: short,
            kind,
            oid: info.oid,
            subject: info.subject,
            time: info.time,
        });
    }
    // Checked-out branch first, then local branches, remotes, tags; newest first within each.
    out.sort_by(|a, b| {
        let rank = |r: &RefInfo| (!r.is_head, r.kind as u8);
        rank(a).cmp(&rank(b)).then(b.time.cmp(&a.time)).then(a.name.cmp(&b.name))
    });
    Ok(out)
}

/// Up to `limit` commits reachable from `HEAD`, newest first.
pub(crate) fn commits(repo: &gix::Repository, limit: usize) -> Result<Vec<CommitInfo>, Error> {
    let Ok(head) = repo.head_commit() else { return Ok(Vec::new()) };
    let walk = head.ancestors().all().map_err(err)?;
    let mut out = Vec::new();
    for info in walk.take(limit) {
        let info = info.map_err(err)?;
        let commit = info.object().map_err(err)?;
        out.push(commit_info(&commit)?);
    }
    Ok(out)
}

pub(crate) fn stashes(repo: &gix::Repository) -> Result<Vec<StashInfo>, Error> {
    let Some(stash) = repo.try_find_reference("refs/stash").map_err(err)? else { return Ok(Vec::new()) };
    let mut log = stash.log_iter();
    let Some(iter) = log.rev().map_err(err)? else { return Ok(Vec::new()) };
    let mut out = Vec::new();
    for (index, line) in iter.flatten().enumerate() {
        out.push(StashInfo {
            index,
            oid: line.new_oid.to_string(),
            message: line.message.to_str_lossy().into_owned(),
            time: line.signature.time.seconds,
        });
    }
    Ok(out)
}

pub(crate) fn commit(repo: &gix::Repository, rev: &str) -> Result<CommitInfo, Error> {
    let id = repo.rev_parse_single(rev).map_err(err)?;
    commit_info(&repo.find_commit(id).map_err(err)?)
}

fn line_counts(before: &[u8], after: &[u8]) -> (u32, u32) {
    let input = InternedInput::new(before, after);
    let diff = Diff::compute(Algorithm::Histogram, &input);
    diff.hunks().fold((0, 0), |(a, r), h| (a + h.after.len() as u32, r + h.before.len() as u32))
}

fn blob(repo: &gix::Repository, id: gix::ObjectId) -> Vec<u8> {
    repo.find_blob(id).map(|b| b.detach().data).unwrap_or_default()
}

pub(crate) fn changes(repo: &gix::Repository, rev: &str) -> Result<Vec<FileChange>, Error> {
    let id = repo.rev_parse_single(rev).map_err(err)?;
    let commit = repo.find_commit(id).map_err(err)?;
    let new_tree = commit.tree().map_err(err)?;
    let parent_tree = match commit.parent_ids().next() {
        Some(p) => Some(repo.find_commit(p).map_err(err)?.tree().map_err(err)?),
        None => None,
    };
    let list = repo.diff_tree_to_tree(parent_tree.as_ref(), Some(&new_tree), None).map_err(err)?;

    let mut out = Vec::new();
    for change in list {
        let (path, kind, before, after) = match change {
            Change::Addition { location, id, entry_mode, .. } if entry_mode.is_blob() => {
                (location.to_str_lossy().into_owned(), Kind::Added, Vec::new(), blob(repo, id))
            }
            Change::Deletion { location, id, entry_mode, .. } if entry_mode.is_blob() => {
                (location.to_str_lossy().into_owned(), Kind::Deleted, blob(repo, id), Vec::new())
            }
            Change::Modification { location, previous_id, id, entry_mode, .. } if entry_mode.is_blob() => {
                (location.to_str_lossy().into_owned(), Kind::Modified, blob(repo, previous_id), blob(repo, id))
            }
            Change::Rewrite { location, source_id, id, .. } => {
                (location.to_str_lossy().into_owned(), Kind::Renamed, blob(repo, source_id), blob(repo, id))
            }
            _ => continue, // trees, submodules
        };
        let binary = before.contains(&0) || after.contains(&0);
        let (added, removed) = if binary { (0, 0) } else { line_counts(&before, &after) };
        out.push(FileChange { path, kind, added, removed, binary });
    }
    out.sort_by(|a, b| a.path.cmp(&b.path));
    Ok(out)
}
