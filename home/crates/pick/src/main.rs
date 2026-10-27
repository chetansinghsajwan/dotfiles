use clap::Parser;
use pick::{Action, Picker, PickerOptions, source};
use ratatui::Terminal;
use ratatui::backend::CrosstermBackend;
use ratatui::crossterm::event::{self, Event};
use ratatui::crossterm::terminal::{EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode};
use ratatui::crossterm::execute;
use std::fs::OpenOptions;
use std::io::{self, IsTerminal, Write};
use std::path::PathBuf;
use std::process::ExitCode;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;

/// Fuzzy picker. Candidates come from stdin or `--files`; the selection is
/// printed to stdout, one per line.
#[derive(Parser)]
#[command(version)]
struct Cli {
    /// Pick from the files under DIR (default: current directory).
    #[arg(long, value_name = "DIR", num_args = 0..=1, default_missing_value = ".")]
    files: Option<PathBuf>,
    /// Treat stdin lines as paths (preview, git state) relative to DIR.
    #[arg(long, value_name = "DIR")]
    paths: Option<PathBuf>,
    /// Initial query.
    #[arg(long, short, default_value = "")]
    query: String,
    #[arg(long)]
    no_preview: bool,
    /// Disable git status colors and signs.
    #[arg(long)]
    no_git: bool,
}

const EXIT_NO_SELECTION: u8 = 1;
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
            eprintln!("pick: {e}");
            ExitCode::from(2)
        }
    }
}

fn run(cli: Cli) -> io::Result<u8> {
    let (root, paths) = match (&cli.files, &cli.paths) {
        (Some(d), _) | (None, Some(d)) => (d.canonicalize()?, true),
        (None, None) => (std::env::current_dir()?, false),
    };
    if cli.files.is_none() && io::stdin().is_terminal() {
        eprintln!("usage: <command> | pick [--paths DIR]   or   pick --files [DIR]");
        return Ok(2);
    }

    let wake = Arc::new(AtomicBool::new(true));
    let notify = {
        let wake = wake.clone();
        Arc::new(move || wake.store(true, Ordering::Relaxed)) as Arc<dyn Fn() + Send + Sync>
    };
    let mut picker = Picker::new(
        PickerOptions { paths, root: root.clone(), preview: !cli.no_preview && paths, git: !cli.no_git, query: cli.query },
        notify,
    );
    if cli.files.is_some() {
        source::spawn_files(picker.injector(), root);
    } else {
        source::spawn_lines(picker.injector(), io::BufReader::new(io::stdin()));
    }

    // Draw on the controlling terminal so stdin can carry candidates and
    // stdout the selection.
    let tty = OpenOptions::new().read(true).write(true).open("/dev/tty")?;
    enable_raw_mode()?;
    let mut tty_term = Tty(Terminal::new(CrosstermBackend::new(tty))?);
    execute!(tty_term.0.backend_mut(), EnterAlternateScreen)?;
    let theme = ui::Theme::load();

    let mut dirty = true;
    let result = loop {
        if wake.swap(false, Ordering::Relaxed) {
            dirty |= picker.tick();
        }
        if dirty {
            tty_term.0.draw(|f| {
                let area = f.area();
                picker.render(area, f.buffer_mut(), &theme);
            })?;
            dirty = false;
        }
        if event::poll(Duration::from_millis(30))? {
            let ev = event::read()?;
            dirty = true;
            if let Event::Key(_) = ev {
                match picker.handle_event(&ev) {
                    Action::None => {}
                    Action::Cancel => break Action::Cancel,
                    Action::Accept(v) => break Action::Accept(v),
                }
            }
        }
        dirty |= picker.tick();
    };
    drop(tty_term);

    match result {
        Action::Accept(sel) if !sel.is_empty() => {
            let mut out = io::stdout().lock();
            for s in sel {
                writeln!(out, "{s}")?;
            }
            Ok(0)
        }
        Action::Accept(_) => Ok(EXIT_NO_SELECTION),
        _ => Ok(EXIT_CANCEL),
    }
}
