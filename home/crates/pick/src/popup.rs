//! Popup mode: inside zellij, `pick` re-runs itself in a floating pane (a real
//! overlay: the screen behind it is untouched) and relays the result. Input and
//! output go through temp files because a new pane does not share this
//! process's stdin and stdout; the exit code comes back through a file too.

use std::ffi::{OsStr, OsString};
use std::io::{self, IsTerminal, Read, Write};
use std::path::{Path, PathBuf};
use std::process::Command;

/// Environment variables the pane should see as this process does (a new pane
/// otherwise inherits the zellij session's environment).
const FORWARD_ENV: [&str; 3] = ["PATH", "UI_THEME", "XDG_CONFIG_HOME"];

/// Popup mode applies inside zellij, unless turned off.
pub fn wanted(no_popup_flag: bool) -> bool {
    !no_popup_flag && std::env::var_os("ZELLIJ").is_some() && std::env::var_os("PICK_NO_POPUP").is_none()
}

/// Single-quote `s` for `sh`.
pub fn quote(s: &str) -> String {
    format!("'{}'", s.replace('\'', r"'\''"))
}

/// Arguments for `zellij`: a floating pane `percent` of the screen, centered,
/// that runs `exe args...` with input from `input` (if any) and output to
/// `out`, then records the exit code in `code`.
#[allow(clippy::too_many_arguments)]
pub fn zellij_args(exe: &Path, args: &[OsString], cwd: &Path, input: Option<&Path>, out: &Path, code: &Path, percent: u16, env: &[(String, String)]) -> Vec<String> {
    let p = percent.clamp(10, 100);
    let offset = (100 - p) / 2;
    let q = |s: &OsStr| quote(&s.to_string_lossy());

    let mut script = String::new();
    for (k, v) in env {
        script.push_str(&format!("{k}={} ", quote(v)));
    }
    script.push_str(&q(exe.as_os_str()));
    for a in args {
        script.push(' ');
        script.push_str(&q(a));
    }
    script.push_str(" --no-popup");
    if let Some(i) = input {
        script.push_str(&format!(" < {}", q(i.as_os_str())));
    }
    script.push_str(&format!(" > {}; echo $? > {}", q(out.as_os_str()), q(code.as_os_str())));

    let mut v: Vec<String> = ["run", "--floating", "--close-on-exit", "--blocking", "--name", "pick"].map(String::from).to_vec();
    // pick draws its own (design-token) border, so the pane has none of its own.
    v.extend(["--borderless".into(), "true".into()]);
    v.extend(["--cwd".into(), cwd.to_string_lossy().into_owned()]);
    v.extend(["--width".into(), format!("{p}%"), "--height".into(), format!("{p}%")]);
    v.extend(["--x".into(), format!("{offset}%"), "--y".into(), format!("{offset}%")]);
    v.extend(["--".into(), "sh".into(), "-c".into(), script]);
    v
}

/// Run `pick` with `args` in a floating pane and return its exit code. The
/// selection is written to this process's stdout. `Err` means the popup could
/// not be opened (the caller can fall back to this terminal).
pub fn run(args: Vec<OsString>, percent: u16) -> io::Result<i32> {
    let dir: PathBuf = std::env::temp_dir().join(format!("pick-popup-{}", std::process::id()));
    std::fs::create_dir_all(&dir)?;
    let result = run_in(&dir, args, percent);
    let _ = std::fs::remove_dir_all(&dir);
    result
}

fn run_in(dir: &Path, args: Vec<OsString>, percent: u16) -> io::Result<i32> {
    let (input, out, code) = (dir.join("in"), dir.join("out"), dir.join("code"));

    // The pane has its own terminal, so piped input is handed over as a file.
    let has_input = !io::stdin().is_terminal();
    if has_input {
        let mut data = Vec::new();
        io::stdin().lock().read_to_end(&mut data)?;
        std::fs::write(&input, data)?;
    }

    let exe = std::env::current_exe()?;
    let cwd = std::env::current_dir()?;
    let env: Vec<(String, String)> = FORWARD_ENV.iter().filter_map(|k| std::env::var(k).ok().map(|v| (k.to_string(), v))).collect();
    let zargs = zellij_args(&exe, &args, &cwd, has_input.then_some(input.as_path()), &out, &code, percent, &env);

    let status = Command::new("zellij").args(&zargs).stdout(std::process::Stdio::null()).status()?;
    if !status.success() {
        return Err(io::Error::other(format!("zellij exited with {status}")));
    }

    if let Ok(selection) = std::fs::read(&out) {
        io::stdout().write_all(&selection)?;
    }
    // No code file: the pane was closed before `pick` finished, which is a cancel.
    Ok(std::fs::read_to_string(&code).ok().and_then(|s| s.trim().parse().ok()).unwrap_or(130))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn quoting_round_trips_through_sh() {
        for s in ["plain", "with space", "it's", "a\"b$c`d", "new\nline", "", "--flag=1"] {
            let out = Command::new("sh").arg("-c").arg(format!("printf %s {}", quote(s))).output().unwrap();
            assert_eq!(String::from_utf8_lossy(&out.stdout), s, "{s:?}");
        }
    }

    #[test]
    fn the_pane_command_is_a_centered_floating_blocking_pane() {
        let args: Vec<OsString> = vec!["--files".into(), "my dir".into(), "--title".into(), "it's".into()];
        let z = zellij_args(
            Path::new("/bin/pick"),
            &args,
            Path::new("/work"),
            Some(Path::new("/t/in")),
            Path::new("/t/out"),
            Path::new("/t/code"),
            80,
            &[("PATH".into(), "/a:/b".into())],
        );
        let has = |a: &str, b: &str| z.windows(2).any(|w| w[0] == a && w[1] == b);
        assert!(z.contains(&"--floating".to_string()) && z.contains(&"--blocking".to_string()) && z.contains(&"--close-on-exit".to_string()));
        assert!(has("--borderless", "true"));
        assert!(has("--width", "80%") && has("--height", "80%") && has("--x", "10%") && has("--y", "10%") && has("--cwd", "/work"));
        let script = z.last().unwrap();
        assert_eq!(
            script,
            "PATH='/a:/b' '/bin/pick' '--files' 'my dir' '--title' 'it'\\''s' --no-popup < '/t/in' > '/t/out'; echo $? > '/t/code'"
        );
        // No piped input: no redirect from `in`. Other sizes are centered too.
        let z = zellij_args(Path::new("/bin/pick"), &[], Path::new("/w"), None, Path::new("/o"), Path::new("/c"), 60, &[]);
        assert!(!z.last().unwrap().contains(" < ") && z.windows(2).any(|w| w[0] == "--x" && w[1] == "20%"));
    }

    #[test]
    fn popup_applies_only_inside_zellij_and_can_be_turned_off() {
        // Flag off always wins; the environment cases are covered by the end-to-end run.
        assert!(!wanted(true));
    }
}
