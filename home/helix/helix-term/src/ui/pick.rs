//! Bridge to the shared `pick` picker (dotfiles/home/crates/pick).
//!
//! `pick` draws with ratatui and reads crossterm events; helix draws on its own
//! `helix-tui` surface and has its own input types. This component owns a
//! `pick::Picker`, converts helix key events for it, renders it into a
//! ratatui buffer, and copies that buffer onto the helix surface. All picker
//! behaviour, layout and design come from `pick` and the shared `ui` tokens;
//! nothing here draws or decides anything itself.

use crate::compositor::{Component, Compositor, Context, Event, EventResult};
use helix_view::graphics::{Color, CursorKind, Modifier, Rect, UnderlineStyle};
use helix_view::input::KeyEvent;
use helix_view::keyboard::{KeyCode, KeyModifiers};
use pick::{Action, Picker, PickerOptions};
use ratatui::buffer::Buffer as RBuffer;
use ratatui::crossterm::event as ct;
use ratatui::layout::Rect as RRect;
use ratatui::style::{Color as RColor, Modifier as RModifier};
use std::sync::Arc;
use tui::buffer::Buffer as Surface;

pub type OnAccept = Box<dyn FnOnce(&mut Compositor, &mut Context, Vec<String>)>;

pub struct PickComponent {
    picker: Picker,
    theme: tui_design::Theme,
    on_accept: Option<OnAccept>,
}

impl PickComponent {
    /// `start` is called with the picker's injector right after creation, to
    /// spawn a candidate source (`pick::source::*`). Grep mode needs none.
    pub fn new(
        opts: PickerOptions,
        start: impl FnOnce(&Picker),
        on_accept: impl FnOnce(&mut Compositor, &mut Context, Vec<String>) + 'static,
    ) -> Self {
        // Search threads wake the editor loop when results change.
        let picker = Picker::new(opts, Arc::new(helix_event::request_redraw));
        start(&picker);
        PickComponent { picker, theme: tui_design::Theme::load(), on_accept: Some(Box::new(on_accept)) }
    }

    /// Put the cursor on the `index`-th entry (the previous buffer, say).
    pub fn with_cursor(mut self, index: u32) -> Self {
        self.picker.set_cursor(index);
        self
    }

    /// Show the list as a directory hierarchy (files, grep results).
    pub fn with_tree(mut self, on: bool) -> Self {
        self.picker.set_tree(on);
        self
    }
}

impl Component for PickComponent {
    fn handle_event(&mut self, event: &Event, _cx: &mut Context) -> EventResult {
        let Event::Key(key) = event else {
            return EventResult::Ignored(None);
        };
        let Some(ev) = to_crossterm(key) else {
            return EventResult::Consumed(None);
        };
        match self.picker.handle_event(&ct::Event::Key(ev)) {
            Action::None => EventResult::Consumed(None),
            Action::Cancel => EventResult::Consumed(Some(Box::new(|compositor, _| {
                compositor.pop();
            }))),
            // `--expect` keys are a CLI feature; inside the editor they accept like Enter.
            Action::Accept(sel) | Action::AcceptWith(_, sel) => {
                let on_accept = self.on_accept.take();
                EventResult::Consumed(Some(Box::new(move |compositor, cx| {
                    compositor.pop();
                    if let Some(f) = on_accept {
                        f(compositor, cx, sel);
                    }
                })))
            }
        }
    }

    fn render(&mut self, area: Rect, surface: &mut Surface, _cx: &mut Context) {
        self.picker.tick();
        // A popup over the editor: `popup_percent` of the screen, centered. Its
        // cells replace what is underneath, and with the `transparent` token they
        // carry no background, so the terminal's own background shows.
        let full = RRect::new(area.x, area.y, area.width, area.height);
        let p = tui_design::layout::popup(&self.theme, full);
        let popup = Rect::new(p.x, p.y, p.width, p.height);
        let r = RRect::new(0, 0, popup.width, popup.height);
        let mut buf = RBuffer::empty(r);
        self.picker.render(r, &mut buf, &self.theme);
        copy(&buf, popup, surface);
    }

    fn cursor(&self, _area: Rect, _editor: &helix_view::Editor) -> (Option<helix_core::Position>, CursorKind) {
        (None, CursorKind::Hidden)
    }
}

/// helix key event to the crossterm one `pick` consumes.
pub(crate) fn to_crossterm(key: &KeyEvent) -> Option<ct::KeyEvent> {
    let code = match key.code {
        KeyCode::Backspace => ct::KeyCode::Backspace,
        KeyCode::Enter => ct::KeyCode::Enter,
        KeyCode::Left => ct::KeyCode::Left,
        KeyCode::Right => ct::KeyCode::Right,
        KeyCode::Up => ct::KeyCode::Up,
        KeyCode::Down => ct::KeyCode::Down,
        KeyCode::Home => ct::KeyCode::Home,
        KeyCode::End => ct::KeyCode::End,
        KeyCode::PageUp => ct::KeyCode::PageUp,
        KeyCode::PageDown => ct::KeyCode::PageDown,
        KeyCode::Tab => ct::KeyCode::Tab,
        KeyCode::Delete => ct::KeyCode::Delete,
        KeyCode::Insert => ct::KeyCode::Insert,
        KeyCode::Esc => ct::KeyCode::Esc,
        KeyCode::Char(c) => ct::KeyCode::Char(c),
        KeyCode::F(n) => ct::KeyCode::F(n),
        _ => return None,
    };
    let mut modifiers = ct::KeyModifiers::NONE;
    if key.modifiers.contains(KeyModifiers::SHIFT) {
        modifiers |= ct::KeyModifiers::SHIFT;
    }
    if key.modifiers.contains(KeyModifiers::CONTROL) {
        modifiers |= ct::KeyModifiers::CONTROL;
    }
    if key.modifiers.contains(KeyModifiers::ALT) {
        modifiers |= ct::KeyModifiers::ALT;
    }
    Some(ct::KeyEvent::new(code, modifiers))
}

fn color(c: RColor) -> Color {
    match c {
        RColor::Reset => Color::Reset,
        RColor::Black => Color::Black,
        RColor::Red => Color::Red,
        RColor::Green => Color::Green,
        RColor::Yellow => Color::Yellow,
        RColor::Blue => Color::Blue,
        RColor::Magenta => Color::Magenta,
        RColor::Cyan => Color::Cyan,
        RColor::Gray => Color::Gray,
        RColor::DarkGray => Color::LightGray,
        RColor::LightRed => Color::LightRed,
        RColor::LightGreen => Color::LightGreen,
        RColor::LightYellow => Color::LightYellow,
        RColor::LightBlue => Color::LightBlue,
        RColor::LightMagenta => Color::LightMagenta,
        RColor::LightCyan => Color::LightCyan,
        RColor::White => Color::White,
        RColor::Rgb(r, g, b) => Color::Rgb(r, g, b),
        RColor::Indexed(i) => Color::Indexed(i),
    }
}

fn modifier(m: RModifier) -> Modifier {
    let mut out = Modifier::empty();
    for (r, h) in [
        (RModifier::BOLD, Modifier::BOLD),
        (RModifier::DIM, Modifier::DIM),
        (RModifier::ITALIC, Modifier::ITALIC),
        (RModifier::SLOW_BLINK, Modifier::SLOW_BLINK),
        (RModifier::RAPID_BLINK, Modifier::RAPID_BLINK),
        (RModifier::REVERSED, Modifier::REVERSED),
        (RModifier::HIDDEN, Modifier::HIDDEN),
        (RModifier::CROSSED_OUT, Modifier::CROSSED_OUT),
    ] {
        if m.contains(r) {
            out |= h;
        }
    }
    out
}

/// Copy a ratatui buffer (origin 0,0) onto the helix surface at `area`.
pub(crate) fn copy(buf: &RBuffer, area: Rect, surface: &mut Surface) {
    for y in 0..area.height {
        for x in 0..area.width {
            let src = &buf[(x, y)];
            let Some(dst) = surface.get_mut(area.x + x, area.y + y) else { continue };
            dst.reset();
            dst.set_symbol(src.symbol());
            dst.fg = color(src.fg);
            dst.bg = color(src.bg);
            dst.modifier = modifier(src.modifier);
            if src.modifier.contains(RModifier::UNDERLINED) {
                dst.underline_style = UnderlineStyle::Line;
            }
        }
    }
}
