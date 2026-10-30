//! `git-ui`: a multi-pane git screen (lazygit's layout): files, branches, commits
//! and stashes on the left, the diff or commit of the highlighted entry on the
//! right. Built on `git-core` (reads through gix, changes through the `git` command
//! line), `git-panel` (the files pane), `pv` (previews) and `ui` (every look).

mod app;

pub use app::{App, Quit};
