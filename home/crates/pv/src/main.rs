use pv::{Options, preview, to_ansi};
use std::path::PathBuf;
use std::process::ExitCode;

fn env_num(name: &str) -> Option<u16> {
    std::env::var(name).ok()?.parse().ok()
}

fn main() -> ExitCode {
    let mut args = std::env::args_os().skip(1);
    let (Some(path), None) = (args.next().map(PathBuf::from), args.next()) else {
        eprintln!("usage: pv <path>");
        return ExitCode::from(1);
    };
    // yazi's piper sets $w and $h to the preview pane size.
    let opts = Options { width: env_num("w"), height: env_num("h") };
    let theme = ui::Theme::load();
    match preview(&path, &theme, &opts) {
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
