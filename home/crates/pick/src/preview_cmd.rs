//! External preview command: `sh -c` with the highlighted line substituted in.
//! `{}` is the whole line, `{N}` its N-th field (1-based), `{N..}` the N-th
//! field to the end. Fields are split on the delimiter, or on whitespace.

use std::process::{Command, Stdio};
use std::sync::mpsc;
use std::thread;
use std::time::Duration;

/// A slow command must not freeze the picker.
const TIMEOUT: Duration = Duration::from_millis(1500);
/// Output kept, in bytes.
const MAX_OUTPUT: usize = 256 * 1024;

#[derive(Debug, Clone)]
pub struct PreviewCmd {
    pub cmd: String,
    pub delimiter: Option<String>,
}

fn quote(s: &str) -> String {
    format!("'{}'", s.replace('\'', r"'\''"))
}

fn fields<'a>(line: &'a str, delimiter: Option<&str>) -> Vec<&'a str> {
    match delimiter {
        Some(d) if !d.is_empty() => line.split(d).collect(),
        _ => line.split_whitespace().collect(),
    }
}

impl PreviewCmd {
    /// The command line for `line`, with every placeholder shell-quoted.
    pub fn expand(&self, line: &str) -> String {
        let parts = fields(line, self.delimiter.as_deref());
        let glue = self.delimiter.as_deref().filter(|d| !d.is_empty()).unwrap_or(" ");
        let mut out = String::new();
        let mut rest = self.cmd.as_str();
        while let Some(start) = rest.find('{') {
            out.push_str(&rest[..start]);
            let after = &rest[start + 1..];
            let Some(end) = after.find('}') else {
                out.push_str(&rest[start..]);
                rest = "";
                break;
            };
            let spec = &after[..end];
            let replacement = if spec.is_empty() {
                Some(quote(line))
            } else if let Some(n) = spec.strip_suffix("..").and_then(|n| n.parse::<usize>().ok()).filter(|&n| n >= 1) {
                Some(quote(&parts.get(n - 1..).map(|p| p.join(glue)).unwrap_or_default()))
            } else {
                spec.parse::<usize>().ok().filter(|&n| n >= 1).map(|n| quote(parts.get(n - 1).copied().unwrap_or("")))
            };
            match replacement {
                Some(r) => out.push_str(&r),
                None => out.push_str(&rest[start..start + 2 + end]), // not ours: leave `{...}` alone
            }
            rest = &after[end + 1..];
        }
        out.push_str(rest);
        out
    }

    /// Run the command for `line` and return its output (stdout then stderr).
    pub fn run(&self, line: &str) -> String {
        let command = self.expand(line);
        let (tx, rx) = mpsc::channel();
        thread::spawn(move || {
            let out = Command::new("sh").arg("-c").arg(&command).stdin(Stdio::null()).output();
            let _ = tx.send(out);
        });
        match rx.recv_timeout(TIMEOUT) {
            Ok(Ok(o)) => {
                let mut text = String::from_utf8_lossy(&o.stdout).into_owned();
                text.push_str(&String::from_utf8_lossy(&o.stderr));
                if text.len() > MAX_OUTPUT {
                    let mut end = MAX_OUTPUT;
                    while !text.is_char_boundary(end) {
                        end -= 1;
                    }
                    text.truncate(end);
                }
                text
            }
            Ok(Err(e)) => format!("preview failed: {e}"),
            Err(_) => "preview timed out".into(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn cmd(c: &str, d: Option<&str>) -> PreviewCmd {
        PreviewCmd { cmd: c.into(), delimiter: d.map(Into::into) }
    }

    #[test]
    fn expands_whole_line_fields_and_ranges_with_quoting() {
        let p = cmd("echo {} / {1} / {2..} / {9} / {x}", None);
        assert_eq!(p.expand("12 it's  fine"), r"echo '12 it'\''s  fine' / '12' / 'it'\''s fine' / '' / {x}");
        let e = cmd("show {1} {2..}", Some("="));
        assert_eq!(e.expand("PATH=/a:/b=c"), "show 'PATH' '/a:/b=c'");
    }

    #[test]
    fn runs_the_command_and_reports_timeouts_and_stderr() {
        assert_eq!(cmd("printf %s {2}", None).run("a b c"), "b");
        assert!(cmd("echo oops >&2", None).run("x").contains("oops"));
        assert_eq!(cmd("sleep 5", None).run("x"), "preview timed out");
    }
}
