# Helix fork

Vendored copy of helix with our changes, kept here so the fork, the shared
crates (`../crates`) and the Nix build live in one repository.

- **Upstream base:** https://github.com/helix-editor/helix, tag `25.07.1`
  (commit `a05c151`). This is the version nixpkgs ships.
- **Not vendored:** upstream's `.git`, `.github`, `book/`, `docs/`, `contrib/`,
  `CHANGELOG.md`, `.envrc`, logos and its Nix files (this repo's formatters skip
  `home/helix/**`, see `treefmt.nix`). Fetched grammars (`runtime/grammars/`)
  are build output and are ignored.
- **Our changes** (everything else is unmodified upstream):
  - `helix-term/Cargo.toml`: path dependencies on `../../crates/pick` and
    `../../crates/ui` (renamed `tui-design`, helix-term has its own `ui`
    module), and `ratatui`.
  - `helix-term/src/ui/pick.rs` (new): the bridge component around
    `pick::Picker`.
  - `helix-term/src/ui/mod.rs`: `pub mod pick;` (and the other new modules below).
  - `helix-term/src/commands.rs`: `open_picked`, `pick_files`, `global_search`
    (on `pick`), the old `global_search` renamed `global_search_builtin`, and the
    three `file_picker*` commands calling `pick_files`.
  - `Cargo.lock`: updated for the new dependency tree.
- **See exactly what changed:** download the base and diff it:
  `git clone --depth 1 --branch 25.07.1 https://github.com/helix-editor/helix /tmp/helix-base`
  then `diff -ru /tmp/helix-base/helix-term home/helix/helix-term`.
- **Build:** `HELIX_DISABLE_AUTO_GRAMMAR_BUILD=1 cargo build -p helix-term`
  from this directory (helix's `build.rs` otherwise fetches grammars, and one
  grammar repository no longer exists). Run with `HELIX_RUNTIME=$PWD/runtime`.
  `rust-toolchain.toml` still pins 1.82, which is too old for `gix`; use a newer
  toolchain (nixpkgs cargo ignores the pin).
- **Upgrading helix:** rebase the changes above onto the new upstream tag; the
  patch is small and confined to `helix-term`.

## Nix

`../helix-fork.nix` builds this tree together with `../crates` (the path
dependencies need both) and reuses nixpkgs' helix wrapper for the runtime and
grammars. Enable it with `dotfiles.editor.helixFork = true`. The base tag must
match the helix version in nixpkgs; rebase this fork first when nixpkgs moves.

## Later changes (docks, panels, popups)

- `helix-term/src/ui/dock.rs` (new): left, right and bottom docks with the `files`
  and `git` panels, assigned through `editor.docks`; `helix-view/src/editor.rs`
  gets `DocksConfig` for that.
- `helix-term/src/ui/editor.rs`: `EditorView` lays out the docks
  (`tui_design::layout::workbench`), routes keys to a focused dock and stretches
  the bottom views' status lines under the side docks.
- `helix-term/src/ui/git_panel.rs` and `ui/pick.rs` (popups), `commands.rs`
  (`git_panel`, `files_panel`, `dock_*`, `buffer_picker`, ...) and
  `keymap/default.rs` (`space g`, `space 1/2/3`, ...).
- Path dependencies now also include `../../crates/files` and
  `../../crates/git-panel`.
