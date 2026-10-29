//! Bookmarks: one key to a folder, kept in `$XDG_STATE_HOME/files/bookmarks`
//! (default `~/.local/state/files/bookmarks`), one `key<TAB>path` per line.

use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Default, Clone)]
pub struct Bookmarks {
    file: Option<PathBuf>,
    map: BTreeMap<char, PathBuf>,
}

/// Where bookmarks live unless told otherwise.
pub fn default_path() -> Option<PathBuf> {
    let state = std::env::var_os("XDG_STATE_HOME").map(PathBuf::from).or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".local/state")))?;
    Some(state.join("files/bookmarks"))
}

impl Bookmarks {
    /// Load from `file` (missing is fine); `None` keeps them in memory only.
    pub fn load(file: Option<PathBuf>) -> Bookmarks {
        let mut map = BTreeMap::new();
        if let Some(text) = file.as_ref().and_then(|f| fs::read_to_string(f).ok()) {
            for line in text.lines() {
                let Some((k, p)) = line.split_once('\t') else { continue };
                let mut chars = k.chars();
                if let (Some(c), None) = (chars.next(), chars.next()) {
                    map.insert(c, PathBuf::from(p));
                }
            }
        }
        Bookmarks { file, map }
    }

    pub fn get(&self, key: char) -> Option<&Path> {
        self.map.get(&key).map(PathBuf::as_path)
    }

    pub fn iter(&self) -> impl Iterator<Item = (char, &Path)> {
        self.map.iter().map(|(k, p)| (*k, p.as_path()))
    }

    pub fn set(&mut self, key: char, path: PathBuf) -> std::io::Result<()> {
        self.map.insert(key, path);
        self.save()
    }

    pub fn remove(&mut self, key: char) -> std::io::Result<bool> {
        let had = self.map.remove(&key).is_some();
        self.save()?;
        Ok(had)
    }

    fn save(&self) -> std::io::Result<()> {
        let Some(file) = &self.file else { return Ok(()) };
        if let Some(dir) = file.parent() {
            fs::create_dir_all(dir)?;
        }
        let text: String = self.map.iter().map(|(k, p)| format!("{k}\t{}\n", p.display())).collect();
        fs::write(file, text)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn set_get_remove_and_reload() {
        let f = std::env::temp_dir().join(format!("files-bm-{}/bookmarks", std::process::id()));
        let mut b = Bookmarks::load(Some(f.clone()));
        assert!(b.get('a').is_none());
        b.set('a', PathBuf::from("/tmp/a b")).unwrap();
        b.set('z', PathBuf::from("/x")).unwrap();
        let again = Bookmarks::load(Some(f.clone()));
        assert_eq!(again.get('a'), Some(Path::new("/tmp/a b")));
        assert_eq!(again.iter().map(|(k, _)| k).collect::<String>(), "az");
        assert!(b.remove('a').unwrap() && !b.remove('a').unwrap());
        assert!(Bookmarks::load(Some(f)).get('a').is_none());
    }

    #[test]
    fn without_a_file_they_stay_in_memory() {
        let mut b = Bookmarks::load(None);
        b.set('q', PathBuf::from("/q")).unwrap();
        assert_eq!(b.get('q'), Some(Path::new("/q")));
    }
}
