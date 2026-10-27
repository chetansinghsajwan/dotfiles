use pv::{Config, Options, preview, to_ansi};
use std::path::PathBuf;
use std::process::ExitCode;

fn env_num(name: &str) -> Option<u16> {
    std::env::var(name).ok()?.parse().ok()
}

fn main() -> ExitCode {
    let mut git = Config::load().git;
    let mut paths = Vec::new();
    for a in std::env::args_os().skip(1) {
        if a == "--no-git" {
            git = false;
        } else {
            paths.push(PathBuf::from(a));
        }
    }
    let [path] = paths.as_slice() else {
        eprintln!("usage: pv [--no-git] <path>");
        return ExitCode::from(1);
    };
    // yazi's piper sets $w and $h to the preview pane size.
    let opts = Options { width: env_num("w"), height: env_num("h"), git };
    let theme = ui::Theme::load();
    match preview(path, &theme, &opts) {
        Ok(lines) => {
            print!("{}", to_ansi(&lines));
            ExitCode::SUCCESS
        }
        Err(e) => {
            eprintln!("pv: {}: {e}", path.display());
            ExitCode::from(1)
        }
    }
}
