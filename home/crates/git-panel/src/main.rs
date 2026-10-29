use clap::Parser;
use git_panel::{Action, Panel};
use ratatui::Terminal;
use ratatui::backend::CrosstermBackend;
use ratatui::crossterm::event::{self, Event};
use ratatui::crossterm::execute;
use ratatui::crossterm::terminal::{EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode};
use std::fs::OpenOptions;
use std::io::{self, Write};
use std::path::PathBuf;
use std::process::ExitCode;
use std::time::Duration;

/// Git status panel: changed files by section, the diff of the highlighted one,
/// stage / unstage / discard / commit. Enter prints the highlighted file's path.
#[derive(Parser)]
#[command(version)]
struct Cli {
    /// A path inside the repository (default: the current directory).
    dir: Option<PathBuf>,
    /// Stay in this terminal instead of opening a floating pane (inside zellij
    /// the panel is a popup by default; `PICK_NO_POPUP=1` also turns that off).
    #[arg(long)]
    no_popup: bool,
}

const EXIT_CANCEL: u8 = 130;

struct Tty(Terminal<CrosstermBackend<std::fs::File>>);

impl Drop for Tty {
    fn drop(&mut self) {
        let _ = disable_raw_mode();
        let _ = execute!(self.0.backend_mut(), LeaveAlternateScreen);
    }
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    match run(cli) {
        Ok(code) => ExitCode::from(code),
        Err(e) => {
            eprintln!("git-panel: {e}");
            ExitCode::from(2)
        }
    }
}

fn run(cli: Cli) -> io::Result<u8> {
    let dir = cli.dir.clone().map(Ok).unwrap_or_else(std::env::current_dir)?;
    let Some(mut panel) = Panel::new(&dir) else {
        eprintln!("git-panel: not a git repository: {}", dir.display());
        return Ok(2);
    };

    // Inside zellij: a floating popup, like `pick`.
    if ui::popup::wanted(cli.no_popup) {
        let percent = ui::Theme::load().layout.popup_percent;
        match ui::popup::run(std::env::args_os().skip(1).collect(), percent) {
            Ok(code) => return Ok(u8::try_from(code).unwrap_or(EXIT_CANCEL)),
            Err(e) => eprintln!("git-panel: popup unavailable ({e}); using this terminal"),
        }
    }

    let tty = OpenOptions::new().read(true).write(true).open("/dev/tty")?;
    enable_raw_mode()?;
    let mut term = Tty(Terminal::new(CrosstermBackend::new(tty))?);
    execute!(term.0.backend_mut(), EnterAlternateScreen)?;
    let theme = ui::Theme::load();

    let chosen = loop {
        term.0.draw(|f| {
            let area = f.area();
            panel.render(area, f.buffer_mut(), &theme);
        })?;
        if event::poll(Duration::from_millis(200))? {
            let ev = event::read()?;
            if let Event::Key(_) = ev {
                match panel.handle_event(&ev) {
                    Action::Open(path) => break Some(path),
                    Action::Close => break None,
                    Action::Changed | Action::None => {}
                }
            }
        }
    };
    drop(term);

    match chosen {
        Some(path) => {
            writeln!(io::stdout().lock(), "{}", path.display())?;
            Ok(0)
        }
        None => Ok(EXIT_CANCEL),
    }
}
