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
- Out of scope: shell and prompt configuration (zsh, starship, direnv). Not part of this work.

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

- Neovim: not decided. Presumably dropped since helix is the editor and neovim is the only other terminal editor. Confirm before removing `home/programs/neovim*`.
- Terminal emulator: ghostty, kitty and gnome-terminal are all configured. Not decided. (Was only relevant for kitty keyboard protocol, now dropped, so low priority.)
- The tool list is incomplete: the user was going to give more tools. Covered so far: picker, TUI design, preview, files, editor, git, layout, docs, monitoring, keyboard, search. Ask for what else is in scope.
- Helix has no stable library or plugin API; the fork must track upstream (rebase on each release).
- Exact name of the flag that disables git features (suggested: `--no-git` plus a config key).
- (resolved) `gix` for `git-core`.

## Current repo state (as of writing)

- Tools configured under `home/programs/`: helix (plain nixpkgs helix 25.07.1; the Steel fork and plugins were dropped in commit 55e0025), yazi, zellij, lazygit, delta, bat/batman, eza, fzf, neovim, btop, tealdeer, ghostty, kitty, kanata-layer-indicator, zed, vscode, etc. `agents.md` describes an older `home/modules/...` layout; the real tree is `home/programs/`.
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
- `chrome`: `border` (rounded|plain|double|thick), `titles`.
- `layout`: `gap` (cells between panes), `padding_x`, `padding_y`, `sidebar_width`, `preview_percent`.
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
1. Replace `fzf` usage in in-scope tools.

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

### yazi + `pick` (step 1 done)

- `z` in yazi now runs the `pick` plugin (`home/programs/yazi/pick.yazi/main.lua`, registered in `yazi.nix`, key bound in `mgr.prepend_keymap`) instead of the built-in `fzf` plugin. It is adapted from yazi 26.9's own preset `fzf.lua`: `ui.hide()`, run `pick --files --dirs` in the current dir, then `cd` (folder result, detected by the trailing `/` pick adds), `reveal` (single file) or `toggle_all` (several, marked with Tab in pick).
- `pick --dirs` (new flag, with `--files`): include folders, marked with a trailing `/`.
- Verified by driving real yazi 26.9.1 (generated config) in a pty with `ya emit-to <id> plugin pick` and a stub `pick` on PATH: cancel (exit 130) does nothing, a folder result enters the folder, a file result reveals it (the control `cd` worked the same way). Evidence came from yazi's debug log (`YAZI_LOG=debug`, watched dirs), not from the screen.
- NOT verified: the real `pick` UI running inside yazi's hidden terminal. In this harness no keystrokes reach any child of yazi (even a plain `read </dev/tty` stub got nothing, and `l`/`q` keys did not move yazi either), so typing a query inside yazi was not tested. `pick` alone works in a pty (section 2). Try `z` in a real terminal after activating the config.
- `S` in yazi now runs `plugin pick grep` (replaces yazi's ripgrep content search): `pick --grep` in the current folder; one result reveals its file, several select the distinct files (yazi cannot open at a line, so the line is dropped). `plugin pick` (key `z`) is unchanged. The plugin takes its mode from `job.args[1]`.
- Gotcha found while testing: yazi compiles plugins with Luau, and assigning to a `for` loop variable makes the whole plugin fail to load silently (the task just hangs as "Run plugin"). Use a fresh local. `luau-analyze` (nixpkgs#luau) is a quick check for syntax errors (ignore its "Unknown global" noise).
- Test harness caveats: keystrokes sent through `script` to yazi are real input (typing `deep` + Enter deleted my test fixture folder); `ui.hide()` hung in the harness after the first hour (a second yazi instance of the user's own was running), so the plugin was re-tested with `ui.hide()` replaced by a no-op. Verified that way: `S` passes `--grep`, a single grep result reveals the file, several results do not navigate, cancel does nothing, `z` still enters a folder result. NOT verified: `ui.hide()` + real `pick` UI in a real terminal (same as the `z` caveat above).
- Next for yazi: step 2/3 (embed the `yazi-*` crates, own drawing) and the theme from tokens are untouched.

## 4. Code editor: helix (fork)

No workarounds. Where helix lacks a feature, fork its source and integrate our tools natively.

- Fork helix. Keep the fork diff small: new code lives in our own crates (`ui`, `pick`, `pv`, `git-core`, files explorer, `git-panel`), and the helix patch is only glue.
- Pickers: replace `helix-term`'s picker component with `pick` as a library, drawn through `ui`. Started: file picker and global search (see status below).
- Files panel: new sidebar component in `helix-term`'s compositor, backed by the embedded `yazi-*` crates.
- Git panel: new sidebar component, backed by `git-panel` / `git-core`.
- Previews: `pv` as a library, in-process.
- Theme and borders: read from the tokens via `ui`, so helix follows the design.
- Read-only mode doubles as the docs viewer.
- Helix has no sidebar or panel system today, hence the fork.

### Helix fork status (spike done: pickers embedded)

- Location: vendored in this repo at `home/helix/` (source only, no upstream history; see `home/helix/FORK.md` for the upstream base, the exact list of our changes and how to diff against upstream). It sits under `home/` next to `home/crates/` because `home` is a path sub-flake and a Nix package must see both. Based on tag 25.07.1 (the version nixpkgs ships here). An older working clone with the two original commits is still at `/home/chetansinghsajwan/src/helix` (branch `pick-integration`), not needed any more. Dotfiles do NOT use the fork yet: the installed `hx` is still nixpkgs helix.
- Nix package: `home/helix-fork.nix` (`pkgs.callPackage ../helix-fork.nix { }`). The editor binary is a `rustPlatform.buildRustPackage` of `home/helix` with `home/crates` beside it (`lib.fileset.toSource` rooted at `home/`, so the `../../crates` path dependencies resolve; local `target/` directories are excluded), `cargoLock` from the fork's `Cargo.lock` (it has no git dependencies, so no output hashes), `HELIX_DISABLE_AUTO_GRAMMAR_BUILD=1`, only `helix-term` built, `doCheck = false`. nixpkgs' own `helix` wrapper is reused through `helix.override { helix-unwrapped = <ours>; }` for the runtime: queries plus the grammars Nix builds, set through `HELIX_RUNTIME`. That reuse is only valid while the fork's base tag equals the version nixpkgs ships (both 25.07.1); on a nixpkgs bump, rebase the fork first (the grammar list comes from nixpkgs' `grammars.json`). The package was not built from nixpkgs' own derivation because that one needs the upstream `book/` and `contrib/`, which are not vendored.
- Opt-in switch: `dotfiles.editor.helixFork` (default `false`, in `config/options.nix`) sets `programs.helix.package` in `home/programs/helix.nix`. Off by default because it has been run only in a pty so far; turned on for the WSL host only (below).
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
