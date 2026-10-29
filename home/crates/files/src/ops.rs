//! File operations behind the panel's keys. Pure functions on paths, no UI:
//! every one either does the whole job or returns an error and leaves things as
//! they were (as far as the filesystem allows).

use std::io;
use std::path::{Component, Path, PathBuf};

fn invalid(msg: &str) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidInput, msg.to_string())
}

/// A relative path that stays inside its base: no `..`, no root, not empty.
fn check_relative(name: &str) -> io::Result<&Path> {
    let p = Path::new(name.trim_end_matches('/'));
    if p.as_os_str().is_empty() {
        return Err(invalid("empty name"));
    }
    if p.components().any(|c| !matches!(c, Component::Normal(_))) {
        return Err(invalid("name must be relative and stay inside the folder"));
    }
    Ok(p)
}

/// Create `name` inside `dir`: a file, or a folder when `name` ends with `/`.
/// Missing parent folders are created. Returns the new path and whether it is a folder.
pub fn create(dir: &Path, name: &str) -> io::Result<(PathBuf, bool)> {
    let rela = check_relative(name)?;
    let path = dir.join(rela);
    if path.symlink_metadata().is_ok() {
        return Err(io::Error::new(io::ErrorKind::AlreadyExists, format!("{} already exists", rela.display())));
    }
    let is_dir = name.ends_with('/');
    if is_dir {
        std::fs::create_dir_all(&path)?;
    } else {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        std::fs::OpenOptions::new().write(true).create_new(true).open(&path)?;
    }
    Ok((path, is_dir))
}

/// Rename `from` to `name` inside `from`'s folder (`name` may contain
/// sub-folders, which are created). Never overwrites.
pub fn rename(from: &Path, name: &str) -> io::Result<PathBuf> {
    let rela = check_relative(name)?;
    let to = from.parent().ok_or_else(|| invalid("no parent folder"))?.join(rela);
    if to == from {
        return Ok(to);
    }
    if to.symlink_metadata().is_ok() {
        return Err(io::Error::new(io::ErrorKind::AlreadyExists, format!("{} already exists", rela.display())));
    }
    if let Some(parent) = to.parent() {
        std::fs::create_dir_all(parent)?;
    }
    std::fs::rename(from, &to)?;
    Ok(to)
}

/// `dest`, or the first free `name copy`, `name copy 2`, ... next to it
/// (the extension stays last: `a copy.txt`).
pub fn unique(dest: PathBuf) -> PathBuf {
    if dest.symlink_metadata().is_err() {
        return dest;
    }
    let stem = dest.file_stem().map(|s| s.to_string_lossy().into_owned()).unwrap_or_default();
    let ext = dest.extension().map(|e| format!(".{}", e.to_string_lossy()));
    for n in 1.. {
        let suffix = if n == 1 { " copy".to_string() } else { format!(" copy {n}") };
        let candidate = dest.with_file_name(format!("{stem}{suffix}{}", ext.as_deref().unwrap_or("")));
        if candidate.symlink_metadata().is_err() {
            return candidate;
        }
    }
    unreachable!()
}

/// Copy a file, symlink or folder (recursively) to `dest`, which must not exist.
pub fn copy(src: &Path, dest: &Path) -> io::Result<()> {
    let meta = src.symlink_metadata()?;
    if meta.file_type().is_symlink() {
        let target = std::fs::read_link(src)?;
        #[cfg(unix)]
        return std::os::unix::fs::symlink(target, dest);
        #[cfg(not(unix))]
        return std::fs::copy(src, dest).map(|_| ());
    }
    if meta.is_dir() {
        if dest.starts_with(src) {
            return Err(invalid("cannot copy a folder into itself"));
        }
        std::fs::create_dir(dest)?;
        for entry in std::fs::read_dir(src)? {
            let entry = entry?;
            copy(&entry.path(), &dest.join(entry.file_name()))?;
        }
        return Ok(());
    }
    std::fs::copy(src, dest).map(|_| ())
}

/// Delete permanently.
pub fn remove(path: &Path) -> io::Result<()> {
    if path.symlink_metadata()?.is_dir() {
        std::fs::remove_dir_all(path)
    } else {
        std::fs::remove_file(path)
    }
}

/// Move `src` to `dest` (which must not exist); across file systems this copies, then removes.
pub fn move_to(src: &Path, dest: &Path) -> io::Result<()> {
    if src.is_dir() && dest.starts_with(src) {
        return Err(invalid("cannot move a folder into itself"));
    }
    match std::fs::rename(src, dest) {
        Ok(()) => Ok(()),
        Err(_) => {
            copy(src, dest)?;
            remove(src)
        }
    }
}

/// Move to the trash (recoverable).
pub fn trash(paths: &[PathBuf]) -> Result<(), String> {
    trash::delete_all(paths).map_err(|e| e.to_string())
}

/// Names to show in the editor for a bulk rename: each path relative to `base`.
pub fn bulk_rename_text(base: &Path, paths: &[PathBuf]) -> String {
    paths.iter().map(|p| format!("{}\n", p.strip_prefix(base).unwrap_or(p).display())).collect()
}

/// Read back an edited bulk-rename text (one new path per line, relative to `base`,
/// same order as `olds`) and return the `(from, to)` pairs that change. Fails, and
/// changes nothing, on a wrong line count, a bad or duplicate name, or a name that
/// exists and is not itself being renamed away.
pub fn plan_bulk_rename(base: &Path, olds: &[PathBuf], edited: &str) -> Result<Vec<(PathBuf, PathBuf)>, String> {
    let lines: Vec<&str> = edited.lines().collect();
    if lines.len() != olds.len() {
        return Err(format!("expected {} names, got {}", olds.len(), lines.len()));
    }
    let mut moves = Vec::new();
    let mut seen = std::collections::BTreeSet::new();
    for (old, line) in olds.iter().zip(&lines) {
        let rela = check_relative(line).map_err(|e| format!("{line:?}: {e}"))?;
        let new = base.join(rela);
        if !seen.insert(new.clone()) {
            return Err(format!("{line:?} appears twice"));
        }
        if new != *old {
            moves.push((old.clone(), new));
        }
    }
    for (_, to) in &moves {
        if to.symlink_metadata().is_ok() && !olds.contains(to) {
            return Err(format!("{} already exists", to.strip_prefix(base).unwrap_or(to).display()));
        }
    }
    Ok(moves)
}

/// Carry out moves from `plan_bulk_rename`. Everything first moves to a temporary
/// name beside its source, so swaps and chains (`a→b`, `b→a`) work.
pub fn apply_moves(moves: &[(PathBuf, PathBuf)]) -> io::Result<()> {
    let mut staged = Vec::new();
    for (i, (from, to)) in moves.iter().enumerate() {
        let tmp = from.with_file_name(format!(".files-bulk-{}-{i}", std::process::id()));
        std::fs::rename(from, &tmp)?;
        staged.push((tmp, to));
    }
    for (tmp, to) in staged {
        if let Some(parent) = to.parent() {
            std::fs::create_dir_all(parent)?;
        }
        std::fs::rename(&tmp, to)?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    fn dir(name: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("files-ops-{}-{name}", std::process::id()));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(&d).unwrap();
        d
    }

    #[test]
    fn create_makes_files_and_folders_and_parents_and_refuses_bad_names() {
        let d = dir("create");
        let (f, is_dir) = create(&d, "new.txt").unwrap();
        assert!(f.is_file() && !is_dir);
        let (sub, is_dir) = create(&d, "a/b/").unwrap();
        assert!(sub.is_dir() && is_dir);
        let (nested, _) = create(&d, "x/y/z.rs").unwrap();
        assert!(nested.is_file());
        assert_eq!(create(&d, "new.txt").unwrap_err().kind(), io::ErrorKind::AlreadyExists);
        for bad in ["", "/", "../escape", "/abs", "a/../../b"] {
            assert_eq!(create(&d, bad).unwrap_err().kind(), io::ErrorKind::InvalidInput, "{bad:?}");
        }
    }

    #[test]
    fn rename_moves_within_the_folder_and_never_overwrites() {
        let d = dir("rename");
        fs::write(d.join("a.txt"), "a").unwrap();
        fs::write(d.join("b.txt"), "b").unwrap();
        assert_eq!(rename(&d.join("a.txt"), "c.txt").unwrap(), d.join("c.txt"));
        assert!(d.join("c.txt").is_file() && !d.join("a.txt").exists());
        assert_eq!(rename(&d.join("c.txt"), "b.txt").unwrap_err().kind(), io::ErrorKind::AlreadyExists);
        assert_eq!(fs::read_to_string(d.join("b.txt")).unwrap(), "b");
        assert_eq!(rename(&d.join("c.txt"), "sub/dir/d.txt").unwrap(), d.join("sub/dir/d.txt"));
        assert!(rename(&d.join("sub/dir/d.txt"), "../../x").is_err());
        // Renaming to itself is a no-op.
        assert_eq!(rename(&d.join("b.txt"), "b.txt").unwrap(), d.join("b.txt"));
    }

    #[test]
    fn unique_keeps_the_extension_last() {
        let d = dir("unique");
        assert_eq!(unique(d.join("a.txt")), d.join("a.txt"));
        fs::write(d.join("a.txt"), "").unwrap();
        assert_eq!(unique(d.join("a.txt")), d.join("a copy.txt"));
        fs::write(d.join("a copy.txt"), "").unwrap();
        assert_eq!(unique(d.join("a.txt")), d.join("a copy 2.txt"));
        fs::create_dir(d.join("dir")).unwrap();
        assert_eq!(unique(d.join("dir")), d.join("dir copy"));
    }

    #[test]
    fn copy_is_recursive_keeps_symlinks_and_refuses_self_copy() {
        let d = dir("copy");
        fs::create_dir_all(d.join("src/inner")).unwrap();
        fs::write(d.join("src/a.txt"), "a").unwrap();
        fs::write(d.join("src/inner/b.txt"), "b").unwrap();
        #[cfg(unix)]
        std::os::unix::fs::symlink("a.txt", d.join("src/link")).unwrap();
        copy(&d.join("src"), &d.join("dst")).unwrap();
        assert_eq!(fs::read_to_string(d.join("dst/inner/b.txt")).unwrap(), "b");
        #[cfg(unix)]
        assert_eq!(fs::read_link(d.join("dst/link")).unwrap(), PathBuf::from("a.txt"));
        assert!(copy(&d.join("src"), &d.join("src/inner/again")).is_err());
    }

    #[test]
    fn move_and_remove_work_on_files_and_folders() {
        let d = dir("move");
        fs::create_dir_all(d.join("f/g")).unwrap();
        fs::write(d.join("f/g/x"), "x").unwrap();
        fs::write(d.join("one"), "1").unwrap();
        move_to(&d.join("one"), &d.join("f/one")).unwrap();
        assert!(d.join("f/one").is_file() && !d.join("one").exists());
        assert!(move_to(&d.join("f"), &d.join("f/g/inside")).is_err());
        remove(&d.join("f")).unwrap();
        assert!(!d.join("f").exists());
    }

    #[test]
    fn trash_removes_the_file_from_its_place() {
        let d = dir("trash");
        let f = d.join("gone.txt");
        fs::write(&f, "x").unwrap();
        // Trash needs a writable trash directory; skip quietly where there is none.
        match trash(&[f.clone()]) {
            Ok(()) => assert!(!f.exists()),
            Err(e) => eprintln!("trash unavailable here: {e}"),
        }
    }

    #[test]
    fn bulk_rename_plans_swaps_and_refuses_bad_edits() {
        let d = dir("bulk");
        for n in ["a", "b", "c"] {
            fs::write(d.join(n), n).unwrap();
        }
        let olds = vec![d.join("a"), d.join("b")];
        assert_eq!(bulk_rename_text(&d, &olds), "a\nb\n");
        // A swap is allowed and works through temporary names.
        let moves = plan_bulk_rename(&d, &olds, "b\na\n").unwrap();
        assert_eq!(moves.len(), 2);
        apply_moves(&moves).unwrap();
        assert_eq!(fs::read_to_string(d.join("a")).unwrap(), "b");
        assert_eq!(fs::read_to_string(d.join("b")).unwrap(), "a");
        // Unchanged lines make no moves; a new folder is created on demand.
        assert!(plan_bulk_rename(&d, &olds, "a\nb\n").unwrap().is_empty());
        apply_moves(&plan_bulk_rename(&d, &olds, "a\nsub/x\n").unwrap()).unwrap();
        assert!(d.join("sub/x").is_file());
        // Refusals.
        let olds = vec![d.join("a"), d.join("c")];
        assert!(plan_bulk_rename(&d, &olds, "a\n").is_err()); // line count
        assert!(plan_bulk_rename(&d, &olds, "z\nz\n").is_err()); // duplicate
        assert!(plan_bulk_rename(&d, &olds, "a\n../up\n").is_err()); // escapes
        assert!(plan_bulk_rename(&d, &olds, "sub/x\nc\n").is_err()); // exists, not renamed away
    }
}
