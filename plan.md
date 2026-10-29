# Plan: standardized terminal toolset

This file is the full context for the work. A new session should read it first.
The repo is a Nix flake (see `agents.md`); this plan is about replacing and unifying the terminal tools under it. Built so far: section 1 (`ui` crate + schema) and `pv` step 1 (section 2).

## Goal and principles

- Standardization: tools should look and behave the same. Today helix, lazygit, neovim and `pv` each show their own preview and styling.
- One tool owns one domain. Other tools integrate with that tool instead of re-implementing it (e.g. the editor uses the files tool and the picker tool).
- Design lives in one place. Changing a design value once (e.g. border radius) changes every tool.
- No workarounds or glue hacks (key injection, floating-pane tricks, shell wrappers). If a tool lacks a feature, fork or embed its source and integrate natively.
- Write our own tools in Rust. Reuse existing libraries as much as possible.
- Terminal only. GUI apps (zed, vscode, gnome apps, browsers, etc.) are out of scope.
- Must work on WSL as well as NixOS and macOS (current machine is WSL2).
- Out of scope: shell and prompt configuration (zsh, starship, direnv), except the picker keybindings the user asked to move to `pick`.

## Domains

| Domain                  | Owner                                                     | Integrates / helpers                                                                                                  |
| ----------------------- | --------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| TUI design              | tokens file + `ui` crate (to build)                       | every tool; one place for colors, borders, spacing                                                                    |
| Picker + search         | `pick` (Rust, `home/crates/pick`; files, stdin, grep, git sources done)                                   | used by every tool that needs a picker. Search (grep, symbols, etc.) is a `pick` source, not a separate tool |
| Preview / rendering     | `pv` (Rust, `home/crates/pv`; step 1 done) | bat, batman, `git-core`                                                                                               |
| Files (browse, explore) | yazi (config/plugins now; yazi crates embedded in helix)  | eza, `pv` as previewer, `pick` as finder, tokens for theme                                                            |
| Editing                 | helix (forked, native integration)                        | files panel, git panel, `pick`, `pv`, `ui` built in as crates                                                         |
| Git                     | `git-panel` (to build, Rust; replaces lazygit)            | `git-core`, delta as diff renderer, embedded in helix                                                                 |
| Layout / sessions       | zellij                                                    | tabs and panes only                                                                                                   |
| Docs / help             | helix in read-only mode, once the fork is ready           | tealdeer, batman until then                                                                                           |
| Monitoring              | btop                                                      | themed from tokens                                                                                                    |
| Keyboard                | kanata (standalone, decided)                              | zellij layer pill. On WSL run `kanata.exe` on the Windows host with the shared `.kbd` config                          |

## Decisions log

- Picker: build our own in Rust (`pick`), not a wrapper around fzf. fzf gets replaced in in-scope tools.
- Search is owned by the picker.
- File explorer: stay on yazi. Embed the `yazi-*` crates as a library for the files panel inside helix. Pin versions (no API stability).
- Editor: fork helix and integrate natively (panels, picker, previews). No zellij or key-injection workarounds.
- Git: write our own Rust git panel on `gix` (decided; `git-core` is built on it). Replaces lazygit.
- Zellij stays, for tabs and panes only.
- Docs: use helix in read-only mode once ready.
- Keyboard: leave to kanata. No terminal-level or zellij-level key remapping. Considered and dropped: kitty keyboard protocol + `keyberon` in our own tools.
- Git status highlighting is on by default, with a flag to disable it (section 5).

## Open questions

- Neovim: dropped (module, config and stylix target removed). Terminal emulator: depends on the environment, keep all configured.
- Tool list: final for now (decided by the user).
- Helix has no stable library or plugin API; the fork must track upstream (rebase on each release).
- Exact name of the flag that disables git features (suggested: `--no-git` plus a config key).
- (resolved) `gix` for `git-core`.

## Current repo state (as of writing)

- Tools configured under `home/programs/`: helix (plain nixpkgs helix 25.07.1; the Steel fork and plugins were dropped in commit 55e0025), yazi, zellij, lazygit, delta, bat/batman, eza, fzf, btop, tealdeer, ghostty, kitty, kanata-layer-indicator, zed, vscode, etc. `agents.md` describes an older `home/modules/...` layout; the real tree is `home/programs/`.
- `pv` is now Rust (`home/crates/pv`), packaged by `home/programs/pv/default.nix` via `home/crates/default.nix` (one `buildRustPackage` helper per workspace crate). `pv.sh` was deleted. It is a plain PATH binary so yazi's `piper` (bare `sh -c`) can call it; piper sets `$w`/`$h` to the pane size and pv reads them.
- Started (uncommitted): `dotfiles.ui` options (`config/options.nix`), `home/programs/ui` (theme.json export), `home/crates/ui` (Rust crate). See section 1.

## 1. TUI design: a UI framework (`ui`)

Goal: `ui` is a framework, not a color file. Change a value once (border glyph, pane gap, padding, split ratios) and every tool built on it changes.
A terminal is a character grid, so "radius" means border glyph set (rounded `╭╮╰╯`, plain, double, thick), and "spacing" means cells.

### Status: wired in (uncommitted)
- Done and verified: crate builds, 2 unit tests pass. Locks updated (`nix flake update home config`; this also bumped stylix, nur, caelestia in the root `flake.lock`). `home/programs/ui` is imported explicitly in `home/programs/default.nix` (directories are not auto-imported, only `.nix` files). `nix eval` of `~/.config/ui/theme.json` gives the real ayu-dark colors. The full home config (`jman-nixos` user `chetansinghsajwan`) builds, and the package installs the `ui-demo` binary (Nix `buildRustPackage` from `home/crates/ui`, `cargoLock.lockFile`).
- Consumers wired to the tokens so far: zellij `pane_frames.rounded_corners` and yazi `full-border` type follow `dotfiles.ui.chrome.border`. Colors for zellij and yazi already came from the same stylix base16 scheme as the tokens, so they match without extra work.
- Not done: the demo was never run in a terminal (needs a TTY), the other host configs (nixos, darwin) were not built, and the home config was built but not activated. `nix flake check` was not run.
- Gotcha: do not run `nix fmt` on the whole repo. It reformats unrelated files (neovim, user.nix, macbook flake, yazi `properties.yazi/main.lua`). Format only files you changed.
- Run the demo: `ui-demo` (after activation), or `cd home/crates/ui && nix shell nixpkgs#cargo nixpkgs#rustc nixpkgs#gcc -c cargo run --bin ui-demo`. Needs `~/.config/ui/theme.json` or `UI_THEME=<file>`; defaults apply if missing. Edit the JSON while it runs: the panes follow (theme mtime is polled).

### Schema (single source)

Defined as options in `config/options.nix` under `dotfiles.ui.{chrome,layout}`; colors come from the stylix base16 scheme. `home/programs/ui/default.nix` writes `~/.config/ui/theme.json`. Groups:

- `colors`: `bg fg muted accent border border_focused selection error warning success info`, `syntax.{comment,keyword,function,string,number,type_,constant,variable,operator}` and `git.{added,modified,deleted,untracked,conflict,renamed}` (roles, never raw hex in a tool).
- `chrome`: `border` (rounded|plain|double|thick), `titles`, `transparent`.
- `layout`: `gap` (cells between panes), `padding_x`, `padding_y`, `sidebar_width`, `preview_percent`, `popup_percent`.
  Planned additions: focus style, icons/separators, scrollbar style, status bar layout.

### `ui` crate (`home/crates/ui`, ratatui 0.30)

- `theme`: loads the JSON at runtime (`$UI_THEME`, else `$XDG_CONFIG_HOME/ui/theme.json`, else `~/.config/ui/theme.json`; missing/invalid falls back to built-in defaults).
- `pane::Pane`: the one place a bordered, titled, padded region is drawn (border glyphs, focus color, padding from the theme). `inner(area)` gives the content rect.
- `layout`: `columns`, `rows`, `sidebar_main_preview`, `main_preview` split with the theme's gap and ratios. Tools get rects from here and never compute their own.
- Rule: our tools draw only through `Pane`/`layout`/widgets built on them. No tool draws its own borders, gaps or colors.
- Planned widgets on top: list, preview pane, prompt, status bar.
- Crates live under `home/crates/` (not repo root) because `home` is a path sub-flake and cannot reference files outside its directory. Cargo workspace root is `home/crates/Cargo.toml` (members `ui`, `pv`, `git-core`, `pick`).

### Third-party tools

- Nix generates each config from the same tokens (yazi, zellij, delta, bat, btop; helix until the fork is ready). Colors are controllable everywhere; layout/border shape only where the tool exposes it (e.g. zellij pane frames and gaps). This is the reason the plan embeds yazi and forks helix: so the framework controls their layout directly.
- TODO verify per tool (from memory, unverified): zellij `pane_frames.rounded_corners`, helix rounded corners, yazi (likely none), lazygit `gui.border` (until replaced).

### Next steps

1. Generate remaining third-party configs from the tokens: delta, bat, btop colors; zellij gap/frames and whatever else each tool exposes. Verify per-tool border options (TODO above).
2. Add widgets to `ui` (list, preview pane, prompt, status bar).
3. `pv` in Rust on `ui`. Then `pick`.

## 2. `pick`: the picker (and search)

Goal: every tool that needs a picker for any purpose uses `pick`. It always has a preview window. Search is a `pick` source.

### Contract

- Input: candidates on stdin, or a named source (files, git refs, grep results, ...).
- Preview: pluggable command, default `pv {}`; in-process via the `pv` library when embedded.
- Output: selection on stdout (or a chooser file). Multi-select supported. Distinct exit code for cancel.
- UI, keys and theme are identical everywhere (via `ui`).
- File mode highlights rows by git status (section 5).

### Implementation (Rust, reuse libraries wherever possible; crate APIs not yet verified)

- Fuzzy matching: `nucleo` (same matcher helix uses).
- TUI: `ratatui` + `crossterm`.
- Query input: `tui-input` (or `tui-textarea`).
- File walking: `ignore` (ripgrep's walker, respects .gitignore). Grep: ripgrep's `grep-*` crates.
- Preview rendering: `bat` crate / `syntect` for highlighting, `ansi-to-tui` to draw ANSI output in ratatui. `pv` is a library crate used in-process, plus a thin CLI.
- CLI args: `clap`. Config: `serde` + `toml`.
- Packaged via Nix (`rustPlatform.buildRustPackage` or crane), wired in `home/programs/`.

### Consumers

- yazi: calls `pick` directly (Lua plugin, `z`) until the explorer is embedded. Done, see below.
- helix fork: `pick` as an in-process library replacing `helix-term`'s picker. No external-process adapter.

### `pv` status (step 1 done)

- Library: `pv::preview(path, &Theme, &Options{width,height}) -> Result<Vec<Line>, Error>` (ratatui lines, so it embeds in-process) and `pv::to_ansi` (truecolor SGR). CLI `pv <path>` prints ANSI, reads `$w`/`$h`, exit 1 with a message for missing/binary files.
- Renderers done: text (syntect `default-fancy` + `two-face` syntax bundle, a syntect theme built from the `ui` `syntax` tokens, line-number gutter, 1 MB cap, binary = NUL in first 8000 bytes) and directory (compact tree: dirs first, at most 2 entries per subfolder then `…`, perms colored + relative mtime flush right).
- Git (done, step 2): text rows changed vs HEAD get a `▎` sign (`▔`/`▁` for removed lines) and a row tint (git color at 18% over bg, padded to `$w`); directory rows get a sign column (`M + A D ? U R`, `•` for a folder with changes beneath) and the name colored by state. Disable with `--no-git` or `git = false` in `~/.config/pv/config.toml` (flag wins; default on). Status is computed once per `pv` call.
- Regressions vs the old shell script, still open: CSV/TSV shown as plain highlighted text (tidy-viewer table dropped; step 3), no file icons in directory rows (add icons to the tokens), ignored files have no `!` sign.
- Not verified: running under yazi's piper (the `$w`/`$h` contract is from the old script's comments), width truncation of long text lines (not done; piper/pane clips them), performance on very large directories.
- Tested: 6 unit tests (text gutter + height, binary, dir ordering and child cap, ANSI reset, git row marks + disable, git dir signs); the Nix build runs them. The packaged binary was run on a real repo: highlight on, off via `--no-git`, off via config. `git-core`'s own tests are not run by the Nix build (helper builds `-p pv` only); run `cargo test` in `home/crates`.

### Build order

1. `pv` library + CLI: text, directory and git highlighting done; CSV table remains.
1. `pick` core: stdin in, selection out, preview via `pv`.
1. Sources (files, git refs, grep: done). Open-editor buffers are not a standalone source: the helix fork feeds them in when it embeds `pick`.
1. yazi integration; helix integration (section 4).
1. Replace `fzf` usage in in-scope tools (done, fzf removed).

### `pick` status (milestone 1 built)

Crate `home/crates/pick` (library + CLI), packaged by `home/programs/pick/default.nix`. Deps: `nucleo` 0.5 (matching, threaded, streaming), `ratatui` 0.30, `tui-input` 0.15 (shares ratatui's crossterm), `ignore` (walker), `clap`, `ui`, `pv`, `git-core`.

- Library: `Picker::new(PickerOptions{paths, root, preview, git, query}, notify)`, `injector()` to stream candidates, `tick()`, `handle_event(&Event) -> Action{None, Accept(Vec<String>), Cancel}`, `render(area, buf, theme)`. This is what the helix fork embeds. CLI is a thin loop around it.
- CLI: `pick --files [DIR]` (walk with `ignore`, .gitignore respected) or `<cmd> | pick [--paths DIR]` (`--paths` makes stdin lines paths: preview + git). `--query`, `--no-preview`, `--no-git`. Selection on stdout, one per line; exit 0 selected, 1 accepted with nothing matched, 2 usage/error, 130 cancelled. The UI draws on `/dev/tty`, so stdin and stdout stay free for candidates and the selection.
- UI (all through `ui`): `Pane` list on the left (prompt + `matched/total` count, match characters in the accent color, selected row bg from the `selection` token, `●` marks), `layout::main_preview` split (honors gap and preview percent), preview pane renders `pv::preview` in-process (cached by candidate and size).
- Keys: type to filter; Up/Down, Ctrl-n/Ctrl-p, PageUp/PageDown; Tab marks and moves down; Enter accepts marked or highlighted; Esc / Ctrl-c / Ctrl-g cancels.
- Git (file candidates): name colored by state plus a right-aligned sign, same signs as `pv`. Disabled by `--no-git`. Status is computed synchronously at startup (not in a thread).
- Tested: 4 headless unit tests (filter + accept, navigation clamp + multi-select, cancel / no match, render list + preview). Run end to end in a pty with `script`: `--files` picked a file by typing a query, stdin mode picked `gamma`, Esc exited 130. The home config builds with `pick` installed (the build runs the 4 tests).
- Not done yet (milestone 2): external preview command (`--preview-cmd`, `{}` placeholder; plan default), config file (git default key), non-path preview for plain text candidates, mouse, `--print0`, `--multi` off switch, query history, startup git status in a thread for big repos, Windows support (uses `/dev/tty`).
- Not verified: behavior on very large candidate sets (millions), resizing, non-UTF-8 paths (they are skipped by the walker), WSL specifics beyond this machine (it ran here, which is WSL2).
- Next: yazi integration (finder via `pick`), fzf replacement in in-scope tools, helix embedding (section 4).

## 3. File explorer: yazi

Yazi is Rust, MIT, built on ratatui (same as the `ui` crate). Reuse in order:

1. Config and plugins only: theme generated from tokens, `pv` as previewer, Lua plugin swapping its built-in find/fzf for `pick`. Border shape stays as yazi hardcodes it.
1. Thin fork as a small patch series: replace yazi's drawing with `ui` widgets and tokens for real border control. Cost: rebasing on each upstream release, so keep patches few. Only for gaps left after step 1.
1. Decided: embed the `yazi-*` crates as a library for the files panel inside helix (section 4). No API stability, so pin versions and upgrade deliberately. Standalone yazi (steps 1-2) stays for use outside the editor.

TODO before step 2: read yazi's source to count how many files touch border and layout drawing.

### `pick` grep source (done)

- CLI: `pick --grep [DIR]` (conflicts with `--files`). The query is a regex (smart case); an invalid regex, typical mid-typing, falls back to a literal search. Output lines are `path:line:col:text` (ripgrep `--vimgrep` format, path relative to DIR). Exit codes as before (0, 1 nothing, 130 cancel).
- Library: `PickerOptions.mode = Mode::Grep`. Each query change cancels the running search (`AtomicBool`), clears the results (`Nucleo::restart(true)`) and starts a new search thread (`pick/src/grep.rs`, on the ripgrep `grep` crate + `ignore`, .gitignore respected, binary files skipped, 20,000 match cap, lines clipped to 400 bytes). Empty query lists nothing. In grep mode nucleo's fuzzy scoring is not used: every result is a match, so the count shows only the number of results.
- Candidates are now `Candidate{display, loc: Option<Loc{path,line,col,text,hit}>}` (`pick/src/candidate.rs`); plain/fuzzy candidates have no `loc`. `Action::Accept` returns `Candidate::output()` strings.
- Rows: `path:line: text` with the path colored by git state, the match in bold accent. Preview: `pv` with the new `Options.focus` (a window centered on the match line, that row highlighted with the `selection` token, gutter numbers kept); pane title `path:line`.
- `pv` gained `Options.focus: Option<u32>` (text files only) and 1 test.
- Tested: 5 grep unit tests (results + output format + columns, query change restarts, invalid regex fallback, preview focus window, empty query) plus the earlier 5; pty end-to-end: typed a query + Enter printed `source.rs:11:1:pub fn spawn_lines(...)`, Esc exit 130, no match exit 1.
- Not done / not verified: no debounce (every keystroke restarts the search; fine on this repo, untested on huge trees), case and regex-mode toggles, search inside a path subset or by glob, multi-line patterns, non-UTF-8 files (skipped by the UTF8 sink), stdin grep results.
- yazi `S` is bound to it (see the yazi section). Patch rendering is done. Next: the helix embed.

### `pick` git sources (done)

- CLI: `pick --git refs|commits|stashes` (conflicts with `--files`, `--grep`, `--paths`; runs in the repo containing the current directory). Prints the ref name (`main`, `origin/main`, `v1`), the full 40-char commit hash, or `stash@{n}`. Exit codes as before. Preview is on by default.
- Candidates: `Candidate.git: Option<GitItem{kind: Branch|Remote|Tag|Commit|Stash, name, oid, subject, time, is_head}>`. The fuzzy text is `name subject`, so a query finds a ref by either (a tag is found through its commit's subject). Rows: `*` marks the checked-out branch, the name is colored by kind (branch accent, remote info, tag/commit warning, stash conflict), subject in the text color.
- Ordering: refs list the checked-out branch first, then local branches, remotes, tags, newest first within each; commits are newest first from HEAD, capped at 5,000.
- `git-core` gained read-only history: `Repo::refs()`, `commits(limit)`, `stashes()`, `commit(rev)`, `changes(rev)` (files changed vs the first parent with `+added -removed` counts, root commit vs the empty tree). `gix` feature `revision` added.
- `pv` gained `pv::preview_commit(root, rev, theme, opts)`: header (hash, author, UTC date + age), message, `N files changed, +a -r`, then one row per file (`A/M/D/R` sign in the git color, counts right-aligned to the pane width). `pick` shows it for ref, commit and stash rows.
- Tested: git-core 8 tests (adds refs incl. annotated tag peeling, log + message + parents + limit, per-file changes incl. add/modify/delete and the root commit, stashes, unborn repo), pick 14 (adds refs order and printed names, query by subject, commit hash + preview content, stash name), pv 9 (adds commit preview + UTC date formatting). Real pty runs: refs, commits, stashes, and a query picked the matching commit.
- Not done / not verified: remote-tracking branches are listed by the code but not covered by a test (no remote in the fixtures), rename detection is whatever gix's default tree diff reports, signed or merge commits (a merge diffs against its first parent only), commit history is not streamed past 5,000, ref/commit rows have no age column, the `stash` entry's preview shows the stash commit (its work-tree changes vs the parent).
- Next: patch rendering in `pv` (shared with the future git panel), then the helix embed.

### Patch rendering (done)

- `git-core`: `Repo::patch(rev) -> Vec<FilePatch{path, kind, binary, hunks: Vec<Hunk{old_start, old_len, new_start, new_len, lines: Vec<PatchLine{kind: Context|Added|Removed, text}>}>}>`. Histogram diff, 3 lines of context, changes whose context would touch are merged into one hunk, start 0 means that side is empty (new/deleted file), binary files have no hunks. The root commit diffs against the empty tree; a merge diffs against its first parent only.
- `pv::preview_commit` now draws the patch under the file list: per file a header (kind sign + path), `@@ -a,b +c,d @@` in the info color, rows with a line-number gutter, `+`/`-` sign and the added/removed rows tinted across the full width with the git tokens. `Options.height` clamps the whole preview; without a height at most 4000 lines are drawn. Context lines are not syntax highlighted (plain text color).
- `pick`: commit/ref/stash previews render in full and scroll: `Ctrl-d` / `Ctrl-u` scroll the preview half a page, moving to another candidate resets it. Text-file previews are still a window at the top (or around the focus line); they do not scroll yet.
- Tested: git-core 10 tests (hunks + context + merging + new/deleted/binary), pv 10, pick 15 (adds scrolling).
- Not done: syntax highlighting inside the patch, word-level diffs, side-by-side view, a file-by-file jump, the `delta` renderer mentioned in the domains table (pv's own renderer is used instead for now), scroll for text previews.

### Directory hierarchy in the list (done)

- Path candidates are shown as a tree: folders as header rows (`▾ src/`), items indented beneath, a folder that holds only one folder merged into one header (`docs/guide/`), folders first (case-insensitive), items by name. Fuzzy filtering still works: only matches and their folders show, and the cursor starts on the best match wherever it is drawn. Up/Down/PageUp/PageDown/Tab walk the items in drawing order (headers are not selectable). Match highlighting applies to the file name; git colors and signs stay on the item rows. Grep results group the same way: the file is the header (merged with its folders), its matches are rows `LINE: text` beneath it, ordered by line.
- On by default for `pick --files` (without `--dirs`/`--only-dirs`), `--paths` and `--grep`, and for helix's file picker (`space f`) and global search; `--flat` turns it off. Library: `Picker::set_tree(bool)` (helix: `PickComponent::with_tree`). It stays flat for buffers, git objects, plain text lists, folder listings, and result sets over 20,000 (`tree_limit`).
- Code: `pick/src/tree.rs` (pure model: a trie of folders, chain merging, draw order) and `render_tree_rows` / `refresh_tree` in `picker.rs`; the tree is rebuilt only when the results change. In tree mode `offset` counts rows, not results.
- Tested: 3 unit tests for the model and 5 for the picker (structure and indentation, navigation order and what Enter prints, filtering and best-match start, the flat fallbacks, grep grouping); 38 `pick` tests pass. Looked at in `tmux` (`pick --files pick`): header, indented files, git signs, filtering.
- Not done: collapsing and expanding folders from the keyboard, folder-level git state on the header rows, highlighting matches that fall in the folder part of a path (only the file name is highlighted), a tree for `--dirs` listings and buffers.

### CLI popup inside zellij (done)

- Inside zellij (`$ZELLIJ` set) the CLI `pick` no longer takes over the terminal: it re-runs itself in a floating pane (`zellij run --floating --blocking --close-on-exit --borderless true --width/--height P% --x/--y (100-P)/2% --cwd <cwd> -- sh -c ...`), `P` being the `layout.popup_percent` design token (default 80), and relays the result. A real overlay: the shell and its output stay visible around it. Every shell picker (Ctrl-R, Alt-T, Alt-C, the menu, the git/docker/nixpkgs/clipboard ones) and yazi's `z` / `S` get it without changes.
- How: `pick/src/popup.rs`. Piped stdin is copied to a temp file the pane reads (the pane has its own terminal), the pane writes the selection to a temp file and its exit code to another, then the parent prints the selection and exits with that code (no code file = pane closed early = 130). `PATH`, `UI_THEME` and `XDG_CONFIG_HOME` are forwarded because a new pane inherits the zellij session's environment. The pane is borderless so only `pick`'s own design-token border shows. If `zellij` cannot be run it prints a note and falls back to the current terminal.
- Turn it off with `--no-popup` or `PICK_NO_POPUP=1`; outside zellij nothing changes (full alternate screen).
- Verified: 3 unit tests (shell quoting round trip, the exact `zellij` command line, off switch) and 6 end-to-end cases through a stand-in `zellij` (select, no match = 1, Esc = 130, `--files` relative to the cwd, `--expect`, usage error = 2); and with the real zellij 0.45.1 inside tmux (isolated socket and config directory): the floating pane opened over the live shell, typing a query + Enter closed it and the shell command got the selection and exit code 0, with a single border.
- NOT verified: inside the user's own zellij config (their layout, `zjstatus` bar, key grabs), over yazi's hidden terminal, a very large stdin (it is copied to a file first), zellij versions other than 0.45.1 (`--blocking` and `--borderless <bool>` exist in 0.45.1), non-zellij terminals (still full screen; an inline, `fzf --height` style mode would be the next step).
- Side effect to know about: zellij keeps session info under `~/.cache/zellij` for every session it starts, so the test runs left a few entries there (`delete-all-sessions` is a global command, not isolated by `ZELLIJ_SOCKET_DIR`; one test session was deleted that way, none of the user's older ones).

### Popup size and transparency (done)

- Two new design tokens, so the look changes in one place: `layout.popup_percent` (Nix `dotfiles.ui.layout.popupPercent`, 10-100, default 80) and `chrome.transparent` (`dotfiles.ui.chrome.transparent`, default `true`). `ui::layout::popup(theme, area)` returns the centered popup rect.
- `ui::Pane` no longer paints a solid `bg` when `transparent` is on, so every pane (pick, the files panel, the CLI `pick`) leaves the terminal's own background, which is translucent with the Ghostty/stylix opacity, like the old fzf popup (`bg -1`). Selection rows and git change tints keep their background on purpose.
- The helix `PickComponent` renders into the popup rect instead of the whole screen; its cells replace what is under the popup, so the editor is hidden inside it and visible around it. The file, grep and buffer pickers all use it.
- Verified in `tmux` (real terminal emulator, 130x40): popup top border at row 4, col 13, bottom border at row 35 = 104x32 cells = 80%, centered; the editor text is visible around it; the popup's plain cells use the default background (`ESC[49m`), only the selection row and git tints set one. `ui` has tests for the popup math and for transparent vs solid panes.
- Not done / not verified: "transparent" here means the terminal's background (the editor behind the popup is hidden); seeing the editor through the popup would need skipping empty cells, not done. The CLI `pick` is a real popup inside zellij (next section) and full screen elsewhere. The files panel is a sidebar, not a popup, so it is not sized by the token. Opacity itself is the terminal's setting, not ours.

### Shell pickers on `pick` (done, at the user's request; shell config was otherwise out of scope)

- `home/programs/fzf/fzf.sh` and `fzf.zsh` (still the module name, sourced into bash and zsh): the keybound pickers now call `pick`. `Ctrl-R` history (`fh`: history file, deduped most-recent-first), `Alt-T` files (`ff`, `-d/--dirs` includes folders), `Alt-C` cd (`pick --files --only-dirs`, then `cd`), `Alt-G` menu (`pick`) with `fs` text search (`pick --grep`), `fp` processes, `fe` environment, `fcmd` commands, `fssh` ssh hosts, and new `fgl` commits, `fgb` branches and tags, `fgs` stashes (`pick --git ...`). The widgets' wiring (insert the result at the cursor, `zle reset-prompt`) is unchanged.
- `pick` additions for this: `--title`, `--only-dirs` (with `--files`), `--preview-cmd CMD` with `--delimiter SEP` (the command runs through `sh -c`, `{}` is the highlighted line, `{N}` its N-th field, `{N..}` from the N-th field on, all shell-quoted; output is parsed for colors with the new shared `ui::ansi::parse`; 1.5 s timeout; scrolls with Ctrl-d / Ctrl-u). Library setters `Picker::set_title` and `set_preview_command`; the options struct is unchanged.
- Dropped versus fzf: `Ctrl-D` files/folders toggle and `Ctrl-E` open-in-editor inside the file picker, `Alt-M` multi toggle (Tab always marks), the in-picker `Ctrl-D` running/all toggle for docker (use `fdps -a`) and the `Ctrl-G` stat/full preview toggle for git, `fe` showing names only (it now shows `NAME=value`), and the previews of `fp`/`fe`/`fcmd`/`fssh` run via `sh`, so zsh-only functions and aliases are not visible to `fcmd`'s `type`.
- fzf is gone from the shell (done): the `git`, `docker`, `nixpkgs` and `clipboard` modules' pickers moved to `pick` too, the `__fzf` wrapper was deleted and `programs.fzf` is no longer enabled anywhere (neovim's telescope-fzf-native plugin is unrelated). The module `home/programs/fzf` became `home/programs/pickers` (`pickers.sh`, `pickers.zsh`; config files under `~/.config/pick-shell/`, `*-pick/` for the others; `__pick_insert_widget`, `pick-*-widget` names). `bat` and `ripgrep` stay enabled for previews.
  - New `pick` options for this: `--header-lines N` (first stdin lines are a fixed header, e.g. docker's table heading), `--expect KEYS` (comma-separated key names such as `ctrl-e,ctrl-x`, `alt-x`, `f2`; pressing one accepts and prints the key name on the first output line, an empty first line means Enter; the fzf `become`/`execute` idiom, the shell function then runs the action), `--with-nth N` (show and match one field, the whole line is still printed and given to `--preview-cmd`). Library: `Action::AcceptWith`, `Picker::set_expect`, `set_header`, `Candidate::with_raw`, `source::spawn_lines_with`.
  - `git` module: `fgl` / `fgb` / `fgs` now call `pick --git commits|refs|stashes` (commit hashes and names are printed instead of the old `hash subject` lines, previews show the patch); `fgt`, `fgst`, `fglf`, `fgr` feed git's output to `pick` with a preview command. `docker`: `fdps` (ctrl-e shell, ctrl-l logs, `-a` for all), `fdimg` (ctrl-e throwaway container), `fdvol`, `fdnet`. `nixpkgs`: `fnp` (ctrl-e opens `nix shell`), `fnpi`. `clipboard`: `fcp` (Enter copies, ctrl-x deletes the entry and reopens the list).
  - Verified in a pty with stub `docker`, `nix`, `nix-store`, `cliphist`, `wl-copy`: every new option, `fdps` (Enter, ctrl-e, ctrl-l), `fnp` (Enter prints the attribute, ctrl-e runs `nix shell nixpkgs#...`), `fnpi`, `fcp` (copies, ctrl-x deletes then reopens), and `fgl`/`fgb`/`fgr` in this repo. NOT verified: real docker, real `cliphist`/Wayland, `fglf`, the zsh keybindings in an interactive shell.
- Verified: `bash -n` and `zsh -n` on both scripts; in a pty with the debug `pick` on PATH (bash and zsh): `fh` returned the right deduped history entry, `ff` and `ff -d`, `fs` returned `sub/c.txt:1:7:...`, `fgl` and `fgb` in this repo, `fssh`, `fp`, `fe` (query `HOME`), `fcmd` under zsh. NOT verified: the ZLE widgets themselves inside an interactive zsh (they call the same functions), anything in zellij, the Nix build of the new scripts until the build below finishes.
- Known quirk: with `^` anchors and uppercase letters the query matches nothing (`^home` works, `^HOME` does not; `$`, `!` and `'` work). Looks like `nucleo`'s smart-case handling; not investigated.

### yazi + `pick` (step 1 done)

- `z` in yazi now runs the `pick` plugin (`home/programs/yazi/pick.yazi/main.lua`, registered in `yazi.nix`, key bound in `mgr.prepend_keymap`) instead of the built-in `fzf` plugin. It is adapted from yazi 26.9's own preset `fzf.lua`: `ui.hide()`, run `pick --files --dirs` in the current dir, then `cd` (folder result, detected by the trailing `/` pick adds), `reveal` (single file) or `toggle_all` (several, marked with Tab in pick).
- `pick --dirs` (new flag, with `--files`): include folders, marked with a trailing `/`.
- Verified by driving real yazi 26.9.1 (generated config) in a pty with `ya emit-to <id> plugin pick` and a stub `pick` on PATH: cancel (exit 130) does nothing, a folder result enters the folder, a file result reveals it (the control `cd` worked the same way). Evidence came from yazi's debug log (`YAZI_LOG=debug`, watched dirs), not from the screen.
- NOT verified: the real `pick` UI running inside yazi's hidden terminal. In this harness no keystrokes reach any child of yazi (even a plain `read </dev/tty` stub got nothing, and `l`/`q` keys did not move yazi either), so typing a query inside yazi was not tested. `pick` alone works in a pty (section 2). Try `z` in a real terminal after activating the config.
- `S` in yazi now runs `plugin pick grep` (replaces yazi's ripgrep content search): `pick --grep` in the current folder; one result reveals its file, several select the distinct files (yazi cannot open at a line, so the line is dropped). `plugin pick` (key `z`) is unchanged. The plugin takes its mode from `job.args[1]`.
- Gotcha found while testing: yazi compiles plugins with Luau, and assigning to a `for` loop variable makes the whole plugin fail to load silently (the task just hangs as "Run plugin"). Use a fresh local. `luau-analyze` (nixpkgs#luau) is a quick check for syntax errors (ignore its "Unknown global" noise).
- Test harness caveats: keystrokes sent through `script` to yazi are real input (typing `deep` + Enter deleted my test fixture folder); `ui.hide()` hung in the harness after the first hour (a second yazi instance of the user's own was running), so the plugin was re-tested with `ui.hide()` replaced by a no-op. Verified that way: `S` passes `--grep`, a single grep result reveals the file, several results do not navigate, cancel does nothing, `z` still enters a folder result. NOT verified: `ui.hide()` + real `pick` UI in a real terminal (same as the `z` caveat above).
- Next for yazi: step 2/3 (embed the `yazi-*` crates, own drawing) and the theme from tokens are untouched.

## 3a. Files panel: own `files` crate (decided, milestone 1 done)

Decision (user, after research): the panel is our own Rust library, NOT embedded yazi. Why: even the lowest yazi crates (`yazi-shared`, `yazi-fs`) depend on `mlua` (Lua 5.5, C build), the yazi workspace locks 557 packages, startup needs about 12 global `init()` calls (tty, emulator queries, vfs, Lua runner, image adapter, watcher, ...) plus global config/theme/keymap statics loaded from `~/.config/yazi`, and it assumes it owns the terminal and its own tokio runtime. This replaces the earlier "embed `yazi-*` crates" decision (sections 3 and 4). Yazi stays as the standalone file manager outside helix.

- Crate `home/crates/files` (ratatui 0.30, `ignore`, `git-core`, `ui`): `Panel::new(root, PanelOptions{hidden, git})`, `handle_event(&Event) -> Action{None, Open(path), Close}`, `render(area, buf, theme, focused)`, `reveal(path)`, `refresh()`, `current()`. Folders first, lazily expanded, `.gitignore` respected (via `ignore`, `.git` skipped), dot files toggled with `.`, git colors plus signs (`•` for a folder with changes beneath it) from `git-core`, drawn through `ui::Pane` so borders, colors and the sidebar width (`layout.sidebar_width`) come from the tokens.
- Keys: `j`/`k`/arrows/Ctrl-n/Ctrl-p, PageUp/PageDown, `g`/`G`, `l`/Right/Enter expand a folder or open a file, `h`/Left collapse or go to the parent, Space toggles, `.` hidden files, `R` refresh, Esc/`q` leave the panel (file operations: see below).
- Helix: `home/helix/helix-term/src/ui/files_panel.rs` (bridge like `pick.rs`) and `EditorView` (`ui/editor.rs`) reserve `sidebar_width` columns on the left (the editor area, bufferline and views shrink), render the panel, and route keys to it while it has focus. `space e` runs `files_panel` (command in `commands.rs`): open on the current file with focus, focus it again if it is open but unfocused, close it if focused. Esc or `q` returns focus to the editor and keeps the panel open. `space E` is still helix's own explorer.
- `git-core` gained `FileStatus::sign()` (the one-cell state sign, moved out of `pv`; `pv` now calls it). `pick` still has its own copy in `git_state`, to be switched.
- Tested: 6 `files` unit tests (ordering, hidden toggle, expand/collapse/parent, open + close actions, reveal + refresh keeps the cursor, `.gitignore` + git state rendering, pane rendering and scrolling). In a pty with the debug build of helix: `space e` opened the panel (title and `docs/` row visible), `k` + Enter expanded `src/`, `j` + Enter opened `src/main.rs`, and an edit typed afterwards landed in `main.rs`.
- File operations (done): `a` create (a name ending in `/` makes a folder; missing parents are created; goes into the folder under the cursor, or next to the file), `r` rename (name prefilled; may contain sub-folders; never overwrites), `d` move to the trash (`trash` crate, recoverable) and `D` delete permanently, both after a `y/n` confirmation, `y` yank (copy) and `x` cut then `p` paste into the folder under the cursor (name clashes become `name copy`, `name copy 2`; a yank can be pasted again, a cut is spent), `Tab` marks rows (the operations apply to the marked rows; Esc clears marks before it closes the panel), `R` refreshes (it was `r`). Inline prompt, confirmation and last message are drawn in the panel's footer row.
  - `files::ops` holds the pure operations (`create`, `rename`, `unique`, `copy` recursive with symlinks kept, `move_to` with a copy+remove fallback across file systems, `remove`, `trash`); names are rejected if absolute or containing `..`.
  - New `Action`s for the host: `Created(path, is_dir)`, `Moved(Vec<(from, to)>)` (renames and cut-paste), `Deleted(Vec<path>)`. Helix opens a newly created file for editing (and gives the editor focus) and moves open buffers' paths on `Moved`, folders included, so a later save goes to the new path.
  - Tested: 12 more unit tests (6 for `ops`, 6 for the panel flows: create, existing-name error and Esc, rename keeping folders open, confirm + marked delete, copy/cut/paste with unique names, footer rendering); `trash` really moved a file on this WSL machine. In a pty with the debug helix: created `new.txt` from the panel (it opened), saved, renamed it to `renamed.txt` from the panel, edited and saved again (the content went to `renamed.txt`, `new.txt` was not recreated); copy-paste produced `README copy.md`; `D` + `y` deleted a file.
  - Not done: live refresh on disk changes (press `R`), mouse, icons, a preview, undo, a standalone `files` binary, closing a buffer whose file was deleted, drag-free moves to an arbitrary folder (paste goes to the folder under the cursor), the trash on hosts without a freedesktop trash directory (it reports the error instead of falling back to deleting). Nix build of the fork with these changes: see the commit.

## 4. Code editor: helix (fork)

No workarounds. Where helix lacks a feature, fork its source and integrate our tools natively.

- Fork helix. Keep the fork diff small: new code lives in our own crates (`ui`, `pick`, `pv`, `git-core`, files explorer, `git-panel`), and the helix patch is only glue.
- Pickers: replace `helix-term`'s picker component with `pick` as a library, drawn through `ui`. Started: file picker and global search (see status below).
- Files panel: sidebar in `helix-term`, backed by our own `files` crate (see 3a; the embedded-yazi idea was dropped).
- Git panel: new sidebar component, backed by `git-panel` / `git-core`.
- Previews: `pv` as a library, in-process.
- Theme and borders: read from the tokens via `ui`, so helix follows the design.
- Read-only mode doubles as the docs viewer.
- Helix has no sidebar or panel system today, hence the fork.

### Helix fork status (spike done: pickers embedded)

- Location: vendored in this repo at `home/helix/` (source only, no upstream history; see `home/helix/FORK.md` for the upstream base, the exact list of our changes and how to diff against upstream). It sits under `home/` next to `home/crates/` because `home` is a path sub-flake and a Nix package must see both. Based on tag 25.07.1 (the version nixpkgs ships here). An older working clone with the two original commits is still at `/home/chetansinghsajwan/src/helix` (branch `pick-integration`), not needed any more. Dotfiles do NOT use the fork yet: the installed `hx` is still nixpkgs helix.
- Nix package: `home/helix-fork.nix` (`pkgs.callPackage ../helix-fork.nix { }`). The editor binary is a `rustPlatform.buildRustPackage` of `home/helix` with `home/crates` beside it (`lib.fileset.toSource` rooted at `home/`, so the `../../crates` path dependencies resolve; local `target/` directories are excluded), `cargoLock` from the fork's `Cargo.lock` (it has no git dependencies, so no output hashes), `HELIX_DISABLE_AUTO_GRAMMAR_BUILD=1`, only `helix-term` built, `doCheck = false`. nixpkgs' own `helix` wrapper is reused through `helix.override { helix-unwrapped = <ours>; }` for the runtime: queries plus the grammars Nix builds, set through `HELIX_RUNTIME`. That reuse is only valid while the fork's base tag equals the version nixpkgs ships (both 25.07.1); on a nixpkgs bump, rebase the fork first (the grammar list comes from nixpkgs' `grammars.json`). The package was not built from nixpkgs' own derivation because that one needs the upstream `book/` and `contrib/`, which are not vendored.
- Opt-in switch: `dotfiles.editor.helixFork` (default `false`, in `config/options.nix`) sets `programs.helix.package` in `home/programs/helix.nix`. Off by default because it has been run only in a pty so far; turned on for the WSL host only (below).
- Docks (done): helix has a left sidebar, a right sidebar and a bottom panel, like VS Code and Zed, and the user assigns panels to them. `editor.docks` (helix config, Nix `dotfiles.editor.docks.{left,right,bottom}`, written to the helix settings only when the fork is on) lists the panels per dock; defaults: left `files`, right `git`, bottom `diagnostics`. Known panels: `files` (the file explorer, with all its file operations) and `git` (the changed files list, compact: no diff pane; `space g` is still the full popup with the diff) and `diagnostics` (below). A dock with several panels shows one at a time with tab labels on its border; `[` and `]` switch while it has focus.
  - Keys: `space e` shows the explorer in the dock it is assigned to (reveals the current file), `space 1` / `space 2` / `space 3` toggle the left / bottom / right dock; the first press opens and focuses it, a press while it is focused closes it, Esc hands the keyboard back to the editor and leaves the dock open. Commands: `files_panel`, `git_dock`, `dock_left`, `dock_right`, `dock_bottom`.
  - Sizes come from the design tokens: `layout.sidebar_width` (30) for both side docks and the new `layout.bottom_height` (12, Nix `dotfiles.ui.layout.bottomHeight`). `ui::layout::workbench` does the geometry (tested): a dock takes at most a third of the width or half of the height and the editor keeps a minimum size.
  - The ribbon (the status lines) is always the very bottom row of the screen, full width, below every dock and the editor box, whether or not a bottom dock is open. The side docks stop one row above it, the bottom dock sits under the editor between them and ends right above it, and the left- and right-most views' status lines are stretched under the side docks. (`ui::layout::workbench` returns it as `ribbon`; a stray `│` from helix's split separator in that row needed a fix: the separator check now compares against the editor area, not the screen.)
  - Code: `helix-term/src/ui/dock.rs` (the `DockPanel` trait, the `files` and `git` adapters, `Dock`, `Docks`), `EditorView` (layout, key routing, status-line stretch) and `commands.rs`; `DocksConfig` in `helix-view/src/editor.rs`. The old `files_panel.rs` sidebar was replaced by this. `git-panel` gained `render_compact` for the narrow list.
  - Verified in `tmux` (120x36) with the debug build: left dock (the dock ends above the last row, the status line `NOR README.md ... 1 sel 1:1` spans the whole width at the bottom), right dock with the git list, bottom dock with two panels and `]` switching between them, both side docks plus the bottom one at once; 4 layout tests for `workbench`.
  - Diagnostics panel (done, bottom dock by default): the problems the language servers reported for the whole workspace (helix's `editor.diagnostics`, so files that are not open are included), grouped by file (paths relative to the workspace, count per file), sorted by path then line then column, one row per problem `● LINE:COL message  source` with the dot in the severity color (`error`, `warning`, `info`, `muted` for hints from the tokens) and only the first line of a long message, cut with `…`. The title shows `diagnostics: N errors, M warnings` and the active filter. Keys: `j`/`k`/arrows/PageUp/PageDown/`g`/`G`, `f` cycles the filter (all, errors + warnings, errors; the cursor stays on the same problem), Enter (or `l`/Right) opens the file at the line and column and gives the keyboard back to the editor, Esc/`q` too. It updates live: the list is re-read every frame the dock is shown (an unchanged list costs a comparison). `space 2` opens and focuses the bottom dock; command `diagnostics_dock` (`:diagnostics-dock`) shows it wherever it is assigned.
  - Code: `home/crates/diagnostics-panel` (editor-independent: `Item`, `Severity`, `Panel::set_items`, `handle_event`, `render`; 5 unit tests: grouping and order, navigation and what Enter opens, filter cycling and cursor stability, unchanged vs changed lists, long messages) and the `DiagnosticsDock` adapter in `helix-term/src/ui/dock.rs` (maps `editor.diagnostics` to items; `DockPanel::render` now receives the editor; new `PanelEvent::OpenAt`).
  - Verified in `tmux` with the real `nil` language server on a Nix file with a syntax error and an unused binding: the dock listed `bad.nix 3:7 Expecting an expression` and `good.nix 2:3 Unused binding` with `diagnostics: 1 error, 1 warning`; `f` filtered and kept the cursor on its problem; Enter opened `good.nix` at 2:3.
  - Not done: a details view for long or multi-line messages, related information and code actions, a per-file collapse, a count badge on the tab or dock, "next problem" navigation from the editor, the source field is empty for servers that do not set it (nil), severity icons are a plain dot.
  - Not done: resizing docks with the keyboard or mouse, remembering open docks between sessions, other panels (a terminal, an outline), drag-and-drop between docks, the compact git panel's diff.
- Editor box (done): the center area is drawn inside a bordered box like the docks (rounded border from the `chrome.border` token, focus color while the editor has the keyboard), with the tab bar (`bufferline`) inside at its top, under the top border. Turn it off with the `chrome.editor_box` token (Nix `dotfiles.ui.chrome.editorBox`, default on); it is also skipped when the editor area is smaller than 24x8.
  - The ribbon stays at the very bottom, below the box and below a bottom dock if there is one. Helix draws a status line as the last row of each view, so the views reach down to that row and the rows between their text and it (the box's bottom border, plus the bottom dock's rows when it is open) are the view's bottom margin; the editor view recomputes it every frame from the layout (`ribbon.y - inner.bottom()`).
  - How: `helix-view/src/view.rs` got `View::bottom_margin` (rows between the text and the status line that belong to the frame); `inner_area()` and `inner_height()` subtract it, which are the only two places that matter. `EditorView` sets it to 1 on the views at the bottom edge each frame (and re-checks the cursor is in view when it changes), gives the views the area inside the box plus the border row and the status row, draws the tabs inside the box, and draws only the border cells over the surface afterwards (`dock::draw_border`).
  - Verified in `tmux`: no docks (box, tabs row with two files open, ribbon below), left + right docks (three aligned boxes, ribbon full width), left + bottom docks (status line inside the center box), `ge` on an 80-line file (line 80 visible) and adding a line (cursor row stays visible), Ctrl-d scrolling.
  - Not done: titles on the editor box (e.g. the file name), per-split boxes, an upstream-friendly way to configure the margin (it is set by the editor view, not a user option), tests for the view margin (checked by hand in a terminal only).
- Buffer picker (done, `home/helix/helix-term/src/commands.rs` `buffer_picker`, `space b`): the open buffers as `pick` candidates (`pick::Buffer{value: doc id, path, flags, focus, text}`), most recently used first, flags `+` modified and `*` current, the previous buffer preselected (`PickComponent::with_cursor(1)`, `Picker::set_cursor`), preview rendered from the buffer's own text (`pv::preview_text`, so unsaved changes show, capped at 1 MiB per buffer) with the cursor line in view and highlighted. Accepting switches to the buffer. helix's own is kept as `buffer_picker_builtin` (dead code).
  - Verified in a pty with the debug build: two buffers listed with `+*` flags, the preview showed the unsaved edit, after `gn` the picker marked `* two.txt` and `space b` + Enter returned to `one.txt` (an edit typed afterwards landed in `one.txt`).
  - Quirk (same as helix's own picker): right after startup the last-opened file has the newest focus time, so the list order is not "current first" until buffers have been switched once.
  - Not done: Ctrl-s / Ctrl-v split opens, closing a buffer from the picker, scratch buffers have no git state, multi-select switches only to the first.
- Enabled: `dotfiles.editor.helixFork = lib.mkForce true` in `hosts/jman-nixos/flake.nix` (the WSL host). Other hosts still use nixpkgs helix (the option defaults to false).
- `treefmt.nix` excludes `home/helix/**` so the formatters and linters skip the vendored source.
- How it integrates (all in `helix-term`): `src/ui/pick.rs` is a `Component` that owns a `pick::Picker`. Helix and `pick` use different TUI stacks (helix-tui, a tui-rs fork + crossterm 0.28 + helix input types, vs ratatui 0.30 + crossterm 0.29), so the component converts helix key events to crossterm ones, renders the picker into a ratatui buffer and copies that buffer cell by cell (color, modifiers, underline) onto the helix surface. The picker thread wakes the editor through `helix_event::request_redraw`. Layout, colors, borders and gap all come from the shared `ui` tokens, not from the helix theme. Accept runs a callback that pops the layer and opens the files.
- Wired: file picker (`space f`, `space F`, buffer-directory picker) via `pick_files`, and global search (`space /`) via `pick` in grep mode, opening the match at its line and column. helix's own `global_search` is kept as `global_search_builtin` (dead code, to keep the diff small); the old file picker code is untouched.
- Build: `HELIX_DISABLE_AUTO_GRAMMAR_BUILD=1 cargo build -p helix-term` (helix's `build.rs` otherwise tries to fetch grammars and one grammar repo 404s). Debug build ~3 min. The repo pins `rust-toolchain.toml` to 1.82; `gix` needs a newer compiler (build used nixpkgs cargo, so the pin is ignored) — bump the pin in the fork.
- Verified: `cargo check`, a debug build and the Nix package build pass. Ran the built `hx` (also the Nix-built one: wrapper runtime, grammar parser and highlight queries OK in `hx --health`) in a pty (script, empty config dir, `HELIX_RUNTIME` = the fork's runtime): Space opens the helix menu, `f` opens the `pick` UI listing the workspace files with the preview showing the file, typing a query + Enter opens the file (shown in helix's statusline). 
- NOT verified / not done: grep mode inside helix (the code path compiles, was not run), multi-select open, mouse, resize while open, the helix `[editor.file-picker]` settings (hidden files, .ignore files, symlinks, max depth) are ignored by `pick`'s own walker, helix's own key conventions (Ctrl-s/Ctrl-v split open, Alt-, etc.) are not implemented in `pick`, remaining helix pickers still use helix's own implementation (buffers, symbols, jumplist, changed files, diagnostics, `:open <dir>` at `commands.rs` ~1367 and ~1404, LSP pickers), no files panel (embedded yazi crates), no git panel, no tests in the fork, no Nix build, never ran against the user's real helix config, rebase onto newer helix releases not tried.
- Next (after the Nix package, done): buffer picker fed from `cx.editor` (the reason `pick` has no standalone buffers source), the helix file-picker settings, split-open keys, then the files panel (yazi crates), then the git panel.

## 5. Git status highlighting (cross-cutting)

- `pv`: highlights the changed rows of a file (added, modified, deleted) using the git status colors.
- `pick` in file mode and the files panel: highlight rows by file git status.
- On by default. A flag disables it (e.g. `--no-git`, with a matching config key).
- One shared Rust crate (`git-core`, on `gix` or `git2`) does repo discovery, per-file status and per-line diffs. `pv`, `pick`, the files panel and `git-panel` all use it, so git logic lives in one place.
- Status is computed once per repo and cached, not per keystroke, so large repos stay fast in the picker.
- Colors come from the tokens (see section 1).

## 5a. `git-core` status (built, library only)

Crate `home/crates/git-core`, on `gix` 0.90 (features `status, blob-diff, index, sha1, parallel`; pure Rust, no libgit2). Decision: `gix`, not `git2`.

- `Repo::discover(path)` (None if not a repo or bare), `root()`, `relative(path)`.
- `Repo::status() -> Status`: repo-wide, keyed by repo-relative path. `FileStatus{staged, unstaged}` with `Kind` = Added, Modified, Deleted, Renamed, Typechange, Untracked, Conflict. `staged` is HEAD vs index, `unstaged` is index vs work tree. `primary()` picks conflict > unstaged > staged. `Status::dir(path)` summarizes a folder from its children. Untracked files are listed individually, not collapsed. Callers must compute once and cache (section 5).
- `Repo::line_changes(path) -> Vec<LineChange>`: work tree vs `HEAD` with the histogram diff. `LineKind` = Added, Modified, Deleted (a `Deleted` marker sits before a line, no row of its own). Missing HEAD blob (new or untracked file) = all lines Added.
- Tests (6, real repos built with the `git` CLI, `nativeCheckInputs = [ git ]` in `home/crates/default.nix`): not a repo, clean repo, staged/unstaged/untracked/deleted + dir summary, merge conflict, line changes, untracked file.
- Not done: ignored files (the `!` sign), submodules (default gix behavior, untested), rename detection tuning, performance on large repos (untested), a way to disable it (the `--no-git` flag belongs to the consumers; `git-core` just is not called).
- Next: wire into `pv` (changed-row highlight in text, git signs in directory rows, `--no-git` + config key), then `pick` file mode and the files panel.

## 5b. Git panel: `git-panel` (milestone 1 done)

Replaces lazygit's main screen. Library plus a standalone binary, built on `git-core`, `pv` and `ui`.

- Design decision: reads go through `git-core` (gix); the changes (stage, unstage, discard, commit) run the `git` command line through `git-core` (`Repo::stage`, `unstage`, `discard`, `create_commit`, ...), the way lazygit does. A pure-gix index writer and committer would be a project of its own and would lose hooks, signing and every edge case of the user's git. Switching to gix later only touches `git-core/src/worktree.rs`.
- `git-core` additions: `Repo::diff_file(path, Side::{Staged, Unstaged})` (HEAD against index, index against work tree; an untracked file counts as all added), `branch()`, `stage`, `stage_all`, `unstage` (works before the first commit), `unstage_all`, `discard(path, untracked)`, `create_commit(message)` (returns `hash subject`, refuses an empty message). `pv` gained `preview_diff` (one file's diff, shares the patch drawing with the commit preview) and shows `?`/`U` signs.
- Panel (`home/crates/git-panel`): sections Conflicts, Staged, Unstaged, Untracked with counts, `▸` cursor, the diff of the highlighted file in a preview pane (staged side for staged files, work-tree side otherwise), branch in the title, a footer for the commit prompt, the discard question and the last message (a refused commit shows its reason above the prompt). Keys: `j`/`k`/arrows, PageUp/PageDown, `g`/`G`; Space toggles stage/unstage (the cursor follows the file into its new section), `s` stage, `u` unstage, `a` stage all, `A` unstage all, `x` discard with a `y/n` question (tracked files are restored from the index, untracked ones are deleted; staged changes are never discarded), `c` commit with a one-line message prompt (needs something staged), `Enter` opens the file, `Ctrl-d`/`Ctrl-u` scroll the diff, `r` refresh, Esc/`q` close. `Action`: `Open(path)`, `Close`, `Changed`, `None`.
- Helix: `ui/git_panel.rs` (popup, sized by the `popup_percent` token, same bridge as `pick.rs`), command `git_panel` in `commands.rs`, bound to `space g` (it replaces the changed-files picker; `changed_file_picker` still exists as a command). Enter opens the file in the editor and closes the panel.
- Standalone: `git-panel [DIR]` (Nix package in `home/programs/git-panel`), draws on `/dev/tty`, prints the chosen file's path on Enter (exit 0), Esc exits 130; inside zellij it opens as a popup like `pick` (`ui::popup` was moved out of `pick` into the shared `ui` crate for this).
- Tested: 6 panel tests (sections and order, Space/s/u/a/A with the cursor following, discard question and never touching staged changes, commit flow incl. the refusal shown above the prompt, Enter and the right side of the diff in the preview, clean repo and non-repo), 3 more `git-core` tests (diff sides, stage/unstage/discard/commit, unstage before the first commit) and 1 `pv` test. The tests set their own git identity because the build sandbox has none. By hand: the standalone binary in `tmux` (stage with Space, `c`, message, Enter: the commit appeared in `git log`) and helix (`space g` opens the popup over the editor, Space stages, `c` with an empty message is refused with the reason above the prompt, a real message commits and shows `committed <hash> <subject>`, `j` + Enter opens the file in the editor).
- Not done: partial staging by hunk or line, stash, amend, branch switching, push/pull/fetch (no network code), a log view and rebase (use `pick --git commits` for browsing history), multi-select, a mouse, conflict resolution, automatic refresh when files change on disk (press `r`), reloading open helix buffers after a discard, retiring lazygit (still installed and configured).
- Not verified: hooks that print or prompt, GPG-signed commits, very large repositories (status is computed on every change), the panel inside the user's real zellij.

## 6. Keyboard: kanata

Kanata stays standalone. On WSL2 a Linux kanata cannot see the Windows keyboard, so run `kanata.exe` on the Windows host with the same `.kbd` config generated from the dotfiles. The zellij layer pill reads layer changes from kanata's TCP port (check how `kanata-layer-indicator.nix` connects; from WSL reach the host via localhost forwarding or host IP).

## Overall build order

1. Tokens (Nix, JSON) and generated third-party themes.
1. Shared crates: `ui`, `git-core`.
1. `pv` (Rust), then `pick`.
1. yazi integration (previewer, finder, theme).
1. Helix fork: picker, files panel, git panel.
1. `git-panel` standalone binary; retire lazygit.
1. Retire fzf and neovim configs in scope (after confirming neovim).

## Working preferences

- Confirm the approach with the user before implementing; don't split files into several without being asked.
- Keep caution callouts short; the repo is git-tracked and reversible.
- Keep this plan file the single source of context; update it as decisions change.

## 3b. Explorer: standalone replacement for yazi (decided)

Decision (user): the `files` explorer becomes the one explorer everywhere (helix panel, other tools, standalone CLI) and replaces yazi. Layout: tree plus a `pv` preview pane (not miller columns).
Required before yazi can go: core file ops (done in `files`), cd on exit and `--chooser-file`, preview pane via `pv`, open-with, bulk rename, tabs, icons, search (via `pick`), git markers (done).
- Icons: done. `ui::icons::{dir,file}` (Nerd Font glyph + color), the same set as yazi, generated into `home/crates/ui/src/icons_data.rs` from yazi's preset theme (MIT). Lookup: folder name, exact file name, extension (all lowercase), then executable / plain fallbacks. Drawn in the `files` panel before the name. Not done: an on/off token, icons in `pick` and `pv` directory rows.
- Next: standalone binary (`files` CLI) with preview pane, cd-on-exit and chooser file; then search via `pick`, open-with, bulk rename, tabs.
