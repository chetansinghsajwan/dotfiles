//! `git-panel`: the shared git status panel (lazygit's main screen): the
//! changed files in sections, the diff of the highlighted one, and stage,
//! unstage, discard and commit. A library that editors embed as a popup, plus a
//! standalone binary. Reads use `git-core` (gix); changes run the `git` command
//! line through `git-core`.

mod panel;

pub use panel::{Action, Panel};
