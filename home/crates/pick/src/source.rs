//! Candidate sources. Each pushes into a `nucleo` injector from its own thread,
//! so the UI stays responsive while candidates stream in.

use crate::candidate::Candidate;
use nucleo::Injector;
use std::io::BufRead;
use std::path::{Path, PathBuf};
use std::thread;

/// Lines from a reader (e.g. stdin), one candidate per line.
pub fn spawn_lines(inj: Injector<Candidate>, reader: impl BufRead + Send + 'static) {
    thread::spawn(move || {
        for line in reader.lines().map_while(Result::ok) {
            if !line.is_empty() {
                inj.push(Candidate::plain(line), |c, cols| cols[0] = c.display.as_str().into());
            }
        }
    });
}

/// Files under `root` (respects .gitignore), as paths relative to `root`. With
/// `dirs`, folders are included too, marked with a trailing `/`.
pub fn spawn_files(inj: Injector<Candidate>, root: PathBuf, dirs: bool) {
    thread::spawn(move || {
        for entry in ignore::WalkBuilder::new(&root).hidden(false).filter_entry(|e| e.file_name() != ".git").build().flatten() {
            let Some(ft) = entry.file_type() else { continue };
            if entry.depth() == 0 || !(ft.is_file() || (dirs && ft.is_dir())) {
                continue;
            }
            let rela: &Path = entry.path().strip_prefix(&root).unwrap_or(entry.path());
            if let Some(s) = rela.to_str() {
                let mut s = s.to_string();
                if ft.is_dir() {
                    s.push('/');
                }
                inj.push(Candidate::plain(s), |c, cols| cols[0] = c.display.as_str().into());
            }
        }
    });
}
