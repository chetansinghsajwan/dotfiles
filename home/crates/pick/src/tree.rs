//! Directory hierarchy for the list: folders as header rows, items indented
//! beneath them, folders that only contain one folder merged (`docs/guide/`).
//! Pure data: the picker feeds it the matched candidates and draws the rows.

use std::collections::{BTreeMap, HashMap};

/// One candidate to place: its position in the matched list, the folders above
/// it, and a key that orders it within its folder.
#[derive(Debug, Clone)]
pub struct Entry {
    pub idx: u32,
    pub dirs: Vec<String>,
    pub sort: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Row {
    /// A folder header at `depth`; `label` may span several folders (`a/b`).
    Dir { depth: u16, label: String },
    /// A candidate (its matched-list index) at `depth`.
    Item { idx: u32, depth: u16 },
}

#[derive(Debug, Default)]
pub struct Tree {
    pub rows: Vec<Row>,
    /// Matched-list indices in the order they are drawn (what Up/Down walk).
    pub order: Vec<u32>,
    /// `row_of[idx]`: the row an item is drawn on.
    pub row_of: HashMap<u32, usize>,
    /// `pos_of[idx]`: its position in `order`.
    pub pos_of: HashMap<u32, usize>,
}

#[derive(Default)]
struct Node {
    dirs: BTreeMap<(String, String), Node>,
    items: Vec<(String, u32)>,
}

pub fn build(entries: Vec<Entry>) -> Tree {
    let mut root = Node::default();
    for e in entries {
        let mut node = &mut root;
        for d in e.dirs {
            node = node.dirs.entry((d.to_lowercase(), d)).or_default();
        }
        node.items.push((e.sort, e.idx));
    }
    let mut tree = Tree::default();
    emit(&root, 0, &mut tree);
    tree
}

fn emit(node: &Node, depth: u16, tree: &mut Tree) {
    // Folders first, then the items of this folder.
    for ((_, name), child) in &node.dirs {
        let mut label = name.clone();
        let mut cur = child;
        while cur.items.is_empty() && cur.dirs.len() == 1 {
            let ((_, next_name), next) = cur.dirs.iter().next().expect("one child");
            label.push('/');
            label.push_str(next_name);
            cur = next;
        }
        tree.rows.push(Row::Dir { depth, label });
        emit(cur, depth + 1, tree);
    }
    let mut items: Vec<&(String, u32)> = node.items.iter().collect();
    items.sort();
    for (_, idx) in items {
        tree.row_of.insert(*idx, tree.rows.len());
        tree.pos_of.insert(*idx, tree.order.len());
        tree.order.push(*idx);
        tree.rows.push(Row::Item { idx: *idx, depth });
    }
}

/// The folder header rows that enclose the row at `at`, outermost first (what stays
/// pinned at the top of the list while that row is the first one shown).
pub fn ancestors(rows: &[Row], at: usize) -> Vec<usize> {
    let depth = match rows.get(at) {
        Some(Row::Dir { depth, .. }) | Some(Row::Item { depth, .. }) => *depth,
        None => return Vec::new(),
    };
    let mut need = depth;
    let mut found = Vec::new();
    for i in (0..at).rev() {
        if need == 0 {
            break;
        }
        if let Row::Dir { depth: d, .. } = &rows[i] {
            if *d < need {
                found.push(i);
                need = *d;
            }
        }
    }
    found.reverse();
    found
}

#[cfg(test)]
mod tests {
    use super::*;

    fn e(idx: u32, path: &str) -> Entry {
        let mut parts: Vec<String> = path.split('/').map(String::from).collect();
        let name = parts.pop().unwrap();
        Entry { idx, dirs: parts, sort: name.to_lowercase() }
    }

    #[test]
    fn ancestors_are_the_enclosing_headers_outermost_first() {
        let t = build(vec![e(0, "README.md"), e(1, "src/b.rs"), e(2, "src/ui/c.rs"), e(3, "docs/x.md")]);
        // rows: docs/, #3, src/, ui/, #2, #1, #0
        assert_eq!(ancestors(&t.rows, 4), vec![2, 3]); // c.rs: src, ui
        assert_eq!(ancestors(&t.rows, 5), vec![2]); // b.rs: src
        assert_eq!(ancestors(&t.rows, 3), vec![2]); // ui/ itself: src
        assert!(ancestors(&t.rows, 6).is_empty()); // README: top level
        assert!(ancestors(&t.rows, 0).is_empty() && ancestors(&t.rows, 99).is_empty());
    }

    fn shape(t: &Tree) -> Vec<String> {
        t.rows
            .iter()
            .map(|r| match r {
                Row::Dir { depth, label } => format!("{}{label}/", "  ".repeat(*depth as usize)),
                Row::Item { idx, depth } => format!("{}#{idx}", "  ".repeat(*depth as usize)),
            })
            .collect()
    }

    #[test]
    fn folders_first_items_indented_and_single_chains_merged() {
        let t = build(vec![e(0, "README.md"), e(1, "src/b.rs"), e(2, "src/a.rs"), e(3, "src/ui/c.rs"), e(4, "docs/guide/x.md"), e(5, "Zed/y.txt")]);
        assert_eq!(
            shape(&t),
            vec![
                "docs/guide/", // docs only holds guide: merged
                "  #4",
                "src/",
                "  ui/",
                "    #3",
                "  #2", // a.rs before b.rs
                "  #1",
                "Zed/", // folders sort case-insensitively
                "  #5",
                "#0",
            ]
        );
        // The walk order skips headers and follows the drawing order.
        assert_eq!(t.order, vec![4, 3, 2, 1, 5, 0]);
        assert_eq!(t.pos_of[&2], 2);
        assert_eq!(t.row_of[&0], 9);
    }

    #[test]
    fn a_folder_with_items_or_siblings_is_not_merged() {
        let t = build(vec![e(0, "a/x.rs"), e(1, "a/b/y.rs"), e(2, "a/c/z.rs")]);
        assert_eq!(shape(&t), vec!["a/", "  b/", "    #1", "  c/", "    #2", "  #0"]);
    }

    #[test]
    fn empty_and_flat_inputs() {
        assert!(build(vec![]).rows.is_empty());
        let t = build(vec![e(0, "b.txt"), e(1, "a.txt")]);
        assert_eq!(shape(&t), vec!["#1", "#0"]);
    }
}
