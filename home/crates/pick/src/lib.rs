//! `pick`: the shared picker. A library (state, key handling, rendering through
//! `ui`) so other tools can embed it in-process, plus a thin CLI in `main.rs`.

mod candidate;
pub mod grep;
mod keys;
mod picker;
mod preview_cmd;
pub mod source;

pub use candidate::{Buffer, Candidate, GitItem, GitKind, Loc};
pub use picker::{Action, Mode, Picker, PickerOptions};
