//! `files`: the standalone file explorer (tree, preview pane, tabs) on the same
//! panel the editors embed.

mod app;

use clap::Parser;
use std::path::PathBuf;
use std::process::ExitCode;

/// File explorer. Prints nothing; use `--chooser-file` to pick files for another
/// program and `--cwd-file` to let the shell follow where you ended up.
#[derive(Parser)]
#[command(version)]
struct Cli {
    /// Folder to start in (default: current directory).
    dir: Option<PathBuf>,
    /// Write the chosen file's path to this file and exit when one is opened.
    #[arg(long, value_name = "FILE")]
    chooser_file: Option<PathBuf>,
    /// On exit, write the folder the explorer was in to this file (for a shell `cd`).
    #[arg(long, value_name = "FILE")]
    cwd_file: Option<PathBuf>,
    /// Show hidden files from the start.
    #[arg(long)]
    hidden: bool,
    /// No preview pane.
    #[arg(long)]
    no_preview: bool,
    /// Disable git status colors and signs.
    #[arg(long)]
    no_git: bool,
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    match app::run(cli.into()) {
        Ok(code) => ExitCode::from(code),
        Err(e) => {
            eprintln!("files: {e}");
            ExitCode::from(2)
        }
    }
}

impl From<Cli> for app::Options {
    fn from(c: Cli) -> Self {
        app::Options {
            dir: c.dir.unwrap_or_else(|| PathBuf::from(".")),
            chooser_file: c.chooser_file,
            cwd_file: c.cwd_file,
            hidden: c.hidden,
            preview: !c.no_preview,
            git: !c.no_git,
        }
    }
}
