//! `pick`: the shared picker. A library (state, key handling, rendering through
//! `ui`) so other tools can embed it in-process, plus a thin CLI in `main.rs`.

mod picker;
pub mod source;

pub use picker::{Action, Picker, PickerOptions};
