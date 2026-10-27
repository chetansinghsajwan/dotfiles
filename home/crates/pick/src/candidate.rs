//! What the picker lists. Plain candidates are just text; grep results also
//! carry where the match is, for the preview and the output.

use std::ops::Range;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Candidate {
    /// Text shown in the list and matched against the query.
    pub display: String,
    pub loc: Option<Loc>,
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

impl Candidate {
    pub fn plain(s: impl Into<String>) -> Self {
        Candidate { display: s.into(), loc: None }
    }

    pub fn grep(loc: Loc) -> Self {
        Candidate { display: format!("{}:{}: {}", loc.path, loc.line, loc.text), loc: Some(loc) }
    }

    /// The path the preview and git state refer to.
    pub fn path(&self) -> &str {
        self.loc.as_ref().map(|l| l.path.as_str()).unwrap_or(&self.display)
    }

    /// What is printed on accept: `path:line:col:text` for matches (ripgrep's
    /// `--vimgrep` format), the text itself otherwise.
    pub fn output(&self) -> String {
        match &self.loc {
            Some(l) => format!("{}:{}:{}:{}", l.path, l.line, l.col, l.text),
            None => self.display.clone(),
        }
    }
}
