use clap::Parser;
use pick::source::GitSource;
use pick::{Action, Mode, Picker, PickerOptions, source};
use ratatui::Terminal;
use ratatui::backend::CrosstermBackend;
use ratatui::crossterm::event::{self, Event};
use ratatui::crossterm::terminal::{EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode};
use ratatui::crossterm::execute;
use std::fs::OpenOptions;
use std::io::{self, BufRead, IsTerminal, Write};
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
    /// Search file contents under DIR (default: current directory). The query is a
    /// regex; results print as `path:line:col:text`.
    #[arg(long, value_name = "DIR", num_args = 0..=1, default_missing_value = ".", conflicts_with = "files")]
    grep: Option<PathBuf>,
    /// List git objects of the repository in the current directory: refs
    /// (branches and tags), commits from HEAD, or stashes. Prints the ref name,
    /// the full commit hash, or `stash@{n}`.
    #[arg(long, value_name = "WHAT", conflicts_with_all = ["files", "grep", "paths"])]
    git: Option<GitWhat>,
    /// Treat stdin lines as paths (preview, git state) relative to DIR.
    #[arg(long, value_name = "DIR")]
    paths: Option<PathBuf>,
    /// With `--files`, include folders too (marked with a trailing `/`).
    #[arg(long)]
    dirs: bool,
    /// With `--files`, list only folders (marked with a trailing `/`).
    #[arg(long, requires = "files", conflicts_with = "dirs")]
    only_dirs: bool,
    /// Title of the list pane.
    #[arg(long)]
    title: Option<String>,
    /// Preview each highlighted line with this shell command; `{}` is the line,
    /// `{N}` its N-th field, `{N..}` from the N-th field on.
    #[arg(long, value_name = "CMD")]
    preview_cmd: Option<String>,
    /// Field separator for `{N}` in `--preview-cmd` (default: whitespace).
    #[arg(long, value_name = "SEP")]
    delimiter: Option<String>,
    /// Show only the N-th field of each stdin line (split on `--delimiter`, default
    /// whitespace); accepting still prints the whole line.
    #[arg(long, value_name = "N")]
    with_nth: Option<usize>,
    /// Treat the first N stdin lines as a fixed header above the list.
    #[arg(long, value_name = "N", default_value_t = 0)]
    header_lines: usize,
    /// Keys that accept and print their name on the first output line (before the
    /// selection), e.g. `--expect ctrl-e,ctrl-x`; an empty first line means Enter.
    #[arg(long, value_name = "KEYS", value_delimiter = ',')]
    expect: Vec<String>,
    /// Stay in this terminal instead of opening a floating pane. Inside zellij,
    /// `pick` opens a popup (a floating pane, sized by the `popup_percent` design
    /// token) by default; `PICK_NO_POPUP=1` also turns it off.
    #[arg(long)]
    no_popup: bool,
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
    let mode = if cli.grep.is_some() { Mode::Grep } else { Mode::Fuzzy };
    let (root, paths) = match (&cli.files, &cli.grep, &cli.paths) {
        (Some(d), _, _) | (None, Some(d), _) | (None, None, Some(d)) => (d.canonicalize()?, true),
        (None, None, None) => (std::env::current_dir()?, false),
    };
    if cli.files.is_none() && cli.grep.is_none() && cli.git.is_none() && io::stdin().is_terminal() {
        eprintln!("usage: <command> | pick [--paths DIR]   or   pick --files [DIR]   or   pick --grep [DIR]   or   pick --git refs|commits|stashes");
        return Ok(2);
    }

    // Inside zellij: open as a floating popup and relay the result.
    if pick::popup::wanted(cli.no_popup) {
        let percent = ui::Theme::load().layout.popup_percent;
        match pick::popup::run(std::env::args_os().skip(1).collect(), percent) {
            Ok(code) => return Ok(u8::try_from(code).unwrap_or(EXIT_CANCEL)),
            Err(e) => eprintln!("pick: popup unavailable ({e}); using this terminal"),
        }
    }

    let wake = Arc::new(AtomicBool::new(true));
    let notify = {
        let wake = wake.clone();
        Arc::new(move || wake.store(true, Ordering::Relaxed)) as Arc<dyn Fn() + Send + Sync>
    };
    let mut picker = Picker::new(
        PickerOptions { mode, paths, root: root.clone(), preview: !cli.no_preview && (paths || cli.git.is_some()), git: !cli.no_git, query: cli.query },
        notify,
    );
    if let Some(title) = &cli.title {
        picker.set_title(title.clone());
    }
    if let Err(e) = picker.set_expect(&cli.expect) {
        eprintln!("pick: {e}");
        return Ok(2);
    }
    if let Some(cmd) = &cli.preview_cmd {
        picker.set_preview_command(cmd.clone(), cli.delimiter.clone());
    }
    match (&cli.files, cli.git, mode) {
        (Some(_), _, _) if cli.only_dirs => source::spawn_dirs(picker.injector(), root),
        (Some(_), _, _) => source::spawn_files(picker.injector(), root, cli.dirs),
        (None, Some(what), _) => source::spawn_git(picker.injector(), root, what.into()),
        (None, None, Mode::Grep) => {} // the picker runs the search itself
        (None, None, Mode::Fuzzy) => {
            let mut reader = io::BufReader::new(io::stdin());
            // The first lines are a fixed header, not candidates.
            let mut header = Vec::new();
            for _ in 0..cli.header_lines {
                let mut line = String::new();
                if reader.read_line(&mut line)? == 0 {
                    break;
                }
                header.push(line.trim_end_matches(['\n', '\r']).to_string());
            }
            picker.set_header(header);
            let fmt = source::LineFormat { with_nth: cli.with_nth, delimiter: cli.delimiter.clone() };
            source::spawn_lines_with(picker.injector(), reader, fmt);
        }
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
                    Action::AcceptWith(k, v) => break Action::AcceptWith(k, v),
                }
            }
        }
        dirty |= picker.tick();
    };
    drop(tty_term);

    // With `--expect`, the first line names the key used (empty for Enter).
    let expecting = !cli.expect.is_empty();
    let (key, selection) = match result {
        Action::Accept(sel) => (String::new(), sel),
        Action::AcceptWith(k, sel) => (k, sel),
        _ => return Ok(EXIT_CANCEL),
    };
    if selection.is_empty() && key.is_empty() {
        return Ok(EXIT_NO_SELECTION);
    }
    let mut out = io::stdout().lock();
    if expecting {
        writeln!(out, "{key}")?;
    }
    for s in selection {
        writeln!(out, "{s}")?;
    }
    Ok(0)
}

#[derive(Clone, Copy, clap::ValueEnum)]
enum GitWhat {
    Refs,
    Commits,
    Stashes,
}

impl From<GitWhat> for GitSource {
    fn from(w: GitWhat) -> Self {
        match w {
            GitWhat::Refs => GitSource::Refs,
            GitWhat::Commits => GitSource::Commits,
            GitWhat::Stashes => GitSource::Stashes,
        }
    }
}
