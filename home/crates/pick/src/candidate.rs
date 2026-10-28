//! What the picker lists. Plain candidates are just text; grep results also
//! carry where the match is, and git items what they point at, for the
//! preview and the output.

use std::ops::Range;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Candidate {
    /// Text shown in the list and matched against the query.
    pub display: String,
    pub loc: Option<Loc>,
    pub git: Option<GitItem>,
    pub buffer: Option<Buffer>,
    /// The whole input line when `display` shows only part of it (`--with-nth`);
    /// that line is what accepting prints and what a preview command receives.
    pub raw: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Loc {
    /// Path relative to the search root.
    pub path: String,
    /// 1-based line and column of the match.
    pub line: u32,
    pub col: u32,
    /// The matching line (trimmed) and the match's byte range within it.
    pub text: String,
    pub hit: Range<usize>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GitKind {
    Branch,
    Remote,
    Tag,
    Commit,
    Stash,
}

/// A ref, commit or stash entry.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GitItem {
    pub kind: GitKind,
    /// Short name (`main`, `v1`), short hash, or `stash@{0}`.
    pub name: String,
    /// What to preview and print: the full commit hash.
    pub oid: String,
    pub subject: String,
    /// Commit time, seconds since the epoch.
    pub time: i64,
    /// The checked-out branch.
    pub is_head: bool,
}

/// An open editor buffer. The host (an editor embedding `pick`) fills it in;
/// `display` is the buffer's name and is what the query matches.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Buffer {
    /// What accepting returns: an id the host maps back to the buffer.
    pub value: String,
    /// Path relative to the picker root, for the git state; `None` for scratch buffers.
    pub path: Option<String>,
    /// Flags shown before the name, e.g. `+` modified, `*` current.
    pub flags: String,
    /// 1-based line to bring into view in the preview (the cursor line).
    pub focus: Option<u32>,
    /// The buffer's text as shown in the editor (unsaved changes included).
    pub text: std::sync::Arc<str>,
}

impl Candidate {
    pub fn plain(s: impl Into<String>) -> Self {
        Candidate { display: s.into(), loc: None, git: None, buffer: None, raw: None }
    }

    pub fn grep(loc: Loc) -> Self {
        Candidate { display: format!("{}:{}: {}", loc.path, loc.line, loc.text), loc: Some(loc), git: None, buffer: None, raw: None }
    }

    /// Matched against the query as `name subject`, so either finds it.
    pub fn git_item(item: GitItem) -> Self {
        Candidate { display: format!("{} {}", item.name, item.subject), loc: None, git: Some(item), buffer: None, raw: None }
    }

    /// Show `display` but keep the whole `line` for output and previews.
    pub fn with_raw(display: impl Into<String>, line: impl Into<String>) -> Self {
        Candidate { display: display.into(), loc: None, git: None, buffer: None, raw: Some(line.into()) }
    }

    pub fn buffer(display: impl Into<String>, buffer: Buffer) -> Self {
        Candidate { display: display.into(), loc: None, git: None, buffer: Some(buffer), raw: None }
    }

    /// The path the preview and git state refer to (file candidates only).
    pub fn path(&self) -> &str {
        if let Some(b) = &self.buffer {
            return b.path.as_deref().unwrap_or(&self.display);
        }
        self.loc.as_ref().map(|l| l.path.as_str()).unwrap_or(&self.display)
    }

    /// What is printed on accept: `path:line:col:text` for matches (ripgrep's
    /// `--vimgrep` format); the name for refs and stashes, the full hash for
    /// commits; the text itself otherwise.
    pub fn output(&self) -> String {
        if let Some(b) = &self.buffer {
            return b.value.clone();
        }
        if let Some(raw) = &self.raw {
            return raw.clone();
        }
        if let Some(l) = &self.loc {
            return format!("{}:{}:{}:{}", l.path, l.line, l.col, l.text);
        }
        match &self.git {
            Some(g) if g.kind == GitKind::Commit => g.oid.clone(),
            Some(g) => g.name.clone(),
            None => self.display.clone(),
        }
    }
}
