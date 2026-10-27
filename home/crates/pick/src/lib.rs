//! `pick`: the shared picker. A library (state, key handling, rendering through
//! `ui`) so other tools can embed it in-process, plus a thin CLI in `main.rs`.

mod candidate;
pub mod grep;
mod picker;
pub mod source;

pub use candidate::{Candidate, GitItem, GitKind, Loc};
pub use picker::{Action, Mode, Picker, PickerOptions};
