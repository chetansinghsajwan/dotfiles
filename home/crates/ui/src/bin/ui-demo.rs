//! Live demo: edit the theme JSON while this runs and the panes follow.
//! `q` quits.

use ratatui::crossterm::event::{self, Event, KeyCode};
use ratatui::widgets::Paragraph;
use std::time::{Duration, SystemTime};
use ui::{layout, Pane, Theme};

fn mtime() -> Option<SystemTime> {
    std::fs::metadata(Theme::path()?).ok()?.modified().ok()
}

fn main() -> std::io::Result<()> {
    let mut term = ratatui::init();
    let mut theme = Theme::load();
    let mut seen = mtime();
    let result = (|| loop {
        term.draw(|f| {
            let [side, main, prev] = layout::sidebar_main_preview(&theme, f.area());
            for (area, title, focused) in [(side, "files", false), (main, "main", true), (prev, "preview", false)] {
                let pane = Pane::new(&theme).title(title).focused(focused);
                let inner = pane.inner(area);
                f.render_widget(pane, area);
                f.render_widget(Paragraph::new(format!("{title}\n{}x{}", inner.width, inner.height)), inner);
            }
        })?;
        if event::poll(Duration::from_millis(200))? {
            if let Event::Key(k) = event::read()? {
                if k.code == KeyCode::Char('q') {
                    return Ok(());
                }
            }
        }
        let now = mtime();
        if now != seen {
            seen = now;
            theme = Theme::load();
        }
    })();
    ratatui::restore();
    result
}
