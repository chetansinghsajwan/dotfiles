use clap::Parser;
use git_ui::{App, Quit};
use ratatui::Terminal;
use ratatui::backend::CrosstermBackend;
use ratatui::crossterm::event::{self, Event};
use ratatui::crossterm::execute;
use ratatui::crossterm::terminal::{Clear, ClearType, EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode};
use std::fs::OpenOptions;
use std::io;
use std::path::PathBuf;
use std::process::ExitCode;
use std::time::Duration;

/// A multi-pane git screen: files, branches, commits and stashes with their diffs.
#[derive(Parser)]
#[command(version)]
struct Cli {
    /// A path inside the repository (default: the current directory).
    dir: Option<PathBuf>,
}

type Term = Terminal<CrosstermBackend<std::fs::File>>;

fn enter(term: &mut Term) -> io::Result<()> {
    enable_raw_mode()?;
    execute!(term.backend_mut(), EnterAlternateScreen, Clear(ClearType::All))?;
    term.clear()
}

fn leave(term: &mut Term) -> io::Result<()> {
    disable_raw_mode()?;
    execute!(term.backend_mut(), LeaveAlternateScreen)
}

fn main() -> ExitCode {
    match run(Cli::parse()) {
        Ok(code) => ExitCode::from(code),
        Err(e) => {
            eprintln!("git-ui: {e}");
            ExitCode::from(2)
        }
    }
}

fn run(cli: Cli) -> io::Result<u8> {
    let dir = cli.dir.map(Ok).unwrap_or_else(std::env::current_dir)?;
    let Some(mut app) = App::new(&dir) else {
        eprintln!("git-ui: not a git repository: {}", dir.display());
        return Ok(2);
    };
    let tty = OpenOptions::new().read(true).write(true).open("/dev/tty")?;
    let mut term: Term = Terminal::new(CrosstermBackend::new(tty))?;
    enter(&mut term)?;
    let result = (|| -> io::Result<()> {
        let mut dirty = true;
        loop {
            if dirty {
                term.draw(|f| {
                    let area = f.area();
                    app.render(area, f.buffer_mut());
                })?;
            }
            if !event::poll(Duration::from_millis(200))? {
                dirty = false;
                continue;
            }
            let ev = event::read()?;
            dirty = true;
            if matches!(ev, Event::Resize(..)) {
                continue;
            }
            match app.handle_event(&ev) {
                Quit::No => {}
                Quit::Yes => return Ok(()),
                Quit::Edit(path) => {
                    leave(&mut term)?;
                    let editor = std::env::var("VISUAL").or_else(|_| std::env::var("EDITOR")).unwrap_or_else(|_| "vi".into());
                    let status = std::process::Command::new("sh").arg("-c").arg(format!("{editor} {}", ui::popup::quote(&path.to_string_lossy()))).status();
                    enter(&mut term)?;
                    app.edited(status.map(|s| s.success()).unwrap_or(false));
                }
            }
        }
    })();
    let _ = leave(&mut term);
    result?;
    Ok(0)
}
