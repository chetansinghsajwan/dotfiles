//! `ui`: shared TUI design framework. Tokens in `theme`, chrome in `pane`,
//! screen splitting in `layout`. Tools draw through these and never compute
//! their own borders, colors or gaps.

pub mod ansi;
pub mod icons;
mod icons_data;
pub mod layout;
pub mod popup;
pub mod pane;
pub mod theme;

pub use pane::Pane;
pub use theme::{Theme, mix};
