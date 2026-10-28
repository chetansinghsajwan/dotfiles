//! `files`: the shared file browser panel. A library (tree model, key handling,
//! rendering through `ui`, git state from `git-core`, file operations) that
//! editors embed as a sidebar; a standalone binary can wrap it later.

pub mod ops;
mod panel;

pub use panel::{Action, Panel, PanelOptions};
