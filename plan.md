# Plan: standardized terminal toolset

This file is the full context for the work. A new session should read it first.
The repo is a Nix flake (see `agents.md`); this plan is about replacing and unifying the terminal tools under it. Built so far: `pv.sh` (a shell script) and the start of section 1 (`ui` crate + schema).

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

| Domain | Owner | Integrates / helpers |
|---|---|---|
| TUI design | tokens file + `ui` crate (to build) | every tool; one place for colors, borders, spacing |
| Picker + search | `pick` (to build, Rust) | used by every tool that needs a picker. Search (grep, symbols, buffers, etc.) is a `pick` source, not a separate tool |
| Preview / rendering | `pv` (to rewrite in Rust; today `home/programs/pv/pv.sh`) | bat, batman, `git-core` |
| Files (browse, explore) | yazi (config/plugins now; yazi crates embedded in helix) | eza, `pv` as previewer, `pick` as finder, tokens for theme |
| Editing | helix (forked, native integration) | files panel, git panel, `pick`, `pv`, `ui` built in as crates |
| Git | `git-panel` (to build, Rust; replaces lazygit) | `git-core`, delta as diff renderer, embedded in helix |
| Layout / sessions | zellij | tabs and panes only |
| Docs / help | helix in read-only mode, once the fork is ready | tealdeer, batman until then |
| Monitoring | btop | themed from tokens |
| Keyboard | kanata (standalone, decided) | zellij layer pill. On WSL run `kanata.exe` on the Windows host with the shared `.kbd` config |

## Decisions log

- Picker: build our own in Rust (`pick`), not a wrapper around fzf. fzf gets replaced in in-scope tools.
- Search is owned by the picker.
- File explorer: stay on yazi. Embed the `yazi-*` crates as a library for the files panel inside helix. Pin versions (no API stability).
- Editor: fork helix and integrate natively (panels, picker, previews). No zellij or key-injection workarounds.
- Git: write our own Rust git panel on `gix` or `git2`. Replaces lazygit.
- Zellij stays, for tabs and panes only.
- Docs: use helix in read-only mode once ready.
- Keyboard: leave to kanata. No terminal-level or zellij-level key remapping. Considered and dropped: kitty keyboard protocol + `keyberon` in our own tools.
- Git status highlighting is on by default, with a flag to disable it (section 5).

## Open questions

- Neovim: not decided. Presumably dropped since helix is the editor and neovim is the only other terminal editor. Confirm before removing `home/programs/neovim*`.
- Terminal emulator: ghostty, kitty and gnome-terminal are all configured. Not decided. (Was only relevant for kitty keyboard protocol, now dropped, so low priority.)
- The tool list is incomplete: the user was going to give more tools. Covered so far: picker, TUI design, preview, files, editor, git, layout, docs, monitoring, keyboard, search. Ask for what else is in scope.
- Helix has no stable library or plugin API; the fork must track upstream. Check how the Steel fork already used here fits as the base.
- Exact name of the flag that disables git features (suggested: `--no-git` plus a config key).
- `gix` vs `git2` for `git-core`.

## Current repo state (as of writing)

- Tools configured under `home/programs/`: helix (+ Steel plugins `helix/plugins/{helix,init,minimap}.scm`, uncommitted), yazi, zellij, lazygit, delta, bat/batman, eza, fzf, neovim, btop, tealdeer, ghostty, kitty, kanata-layer-indicator, zed, vscode, etc. `agents.md` describes an older `home/modules/...` layout; the real tree is `home/programs/`.
- `pv` is a shell script (`home/programs/pv/pv.sh`) wrapped by `writeShellApplication`. It dispatches: tidy-viewer for CSV/TSV, bat for text, eza for directories. It is a plain PATH binary so yazi's `piper` previewer (bare `sh -c`) can call it; yazi sets `$h` to the preview height.
- Uncommitted changes in the working tree (not from this plan): `flake.lock`, `home/flake.nix`, `home/programs/helix.nix`, the helix Steel plugins.
- Started (uncommitted): `dotfiles.ui` options (`config/options.nix`), `home/programs/ui` (theme.json export), `home/crates/ui` (Rust crate). See section 1.

## 1. TUI design: a UI framework (`ui`)

Goal: `ui` is a framework, not a color file. Change a value once (border glyph, pane gap, padding, split ratios) and every tool built on it changes.
A terminal is a character grid, so "radius" means border glyph set (rounded `╭╮╰╯`, plain, double, thick), and "spacing" means cells.

### Status: started
- Schema, Nix export and `ui` crate skeleton exist (below). Verified: crate builds, 2 unit tests pass, the Nix module output was checked standalone with stubbed stylix colors and its keys match the Rust structs.
- NOT verified: full flake eval of the new module. `nix eval` through the host flakes with `--override-input` fails on an unrelated pre-existing `local.nix` store-path error, and the root flake pins the `home`/`config` path inputs in `flake.lock`, so the new `dotfiles.ui` option and module are not seen until those locks are updated (`nix flake update home config`, which also touches the already-modified `flake.lock`). Do that deliberately, then eval and build the home config.
- Not packaged yet: no Nix package for the demo, nothing installs `ui` anywhere. Build locally with `cd home/crates/ui && nix shell nixpkgs#cargo nixpkgs#rustc nixpkgs#gcc -c cargo run --example demo` (needs `~/.config/ui/theme.json` or `UI_THEME=<file>`; defaults apply if missing). Edit the JSON while it runs: the panes follow (theme mtime is polled).

### Schema (single source)
Defined as options in `config/options.nix` under `dotfiles.ui.{chrome,layout}`; colors come from the stylix base16 scheme. `home/programs/ui/default.nix` writes `~/.config/ui/theme.json`. Groups:
- `colors`: `bg fg muted accent border border_focused selection error warning success info` and `git.{added,modified,deleted,untracked,conflict,renamed}` (roles, never raw hex in a tool).
- `chrome`: `border` (rounded|plain|double|thick), `titles`.
- `layout`: `gap` (cells between panes), `padding_x`, `padding_y`, `sidebar_width`, `preview_percent`.
Planned additions: focus style, icons/separators, scrollbar style, status bar layout.

### `ui` crate (`home/crates/ui`, ratatui 0.30)
- `theme`: loads the JSON at runtime (`$UI_THEME`, else `$XDG_CONFIG_HOME/ui/theme.json`, else `~/.config/ui/theme.json`; missing/invalid falls back to built-in defaults).
- `pane::Pane`: the one place a bordered, titled, padded region is drawn (border glyphs, focus color, padding from the theme). `inner(area)` gives the content rect.
- `layout`: `columns`, `rows`, `sidebar_main_preview`, `main_preview` split with the theme's gap and ratios. Tools get rects from here and never compute their own.
- Rule: our tools draw only through `Pane`/`layout`/widgets built on them. No tool draws its own borders, gaps or colors.
- Planned widgets on top: list, preview pane, prompt, status bar.
- Crates live under `home/crates/` (not repo root) because `home` is a path sub-flake and cannot reference files outside its directory. Cargo workspace root not created yet; add `home/crates/Cargo.toml` when a second crate appears.

### Third-party tools
- Nix generates each config from the same tokens (yazi, zellij, delta, bat, btop; helix until the fork is ready). Colors are controllable everywhere; layout/border shape only where the tool exposes it (e.g. zellij pane frames and gaps). This is the reason the plan embeds yazi and forks helix: so the framework controls their layout directly.
- TODO verify per tool (from memory, unverified): zellij `pane_frames.rounded_corners`, helix rounded corners, yazi (likely none), lazygit `gui.border` (until replaced).

### Next steps
1. Update locks, eval and build the home config with the new module.
2. Generate third-party configs from the tokens (start with colors: zellij, yazi).
3. Package the `ui` crate in Nix (`rustPlatform.buildRustPackage`, set `cargoHash`) with the demo binary.
4. Add widgets (list, preview pane, prompt, status bar); then `pv` and `pick` build on `ui`.

## 2. `pick`: the picker (and search)

Goal: every tool that needs a picker for any purpose uses `pick`. It always has a preview window. Search is a `pick` source.

### Contract
- Input: candidates on stdin, or a named source (files, buffers, git refs, grep results, ...).
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
- yazi: calls `pick` directly (Lua plugin) until the explorer is embedded.
- helix fork: `pick` as an in-process library replacing `helix-term`'s picker. No external-process adapter.

### Build order
1. `pv` library + CLI (port from `pv.sh`).
2. `pick` core: stdin in, selection out, preview via `pv`.
3. Sources (files, buffers, git refs, grep).
4. yazi integration; helix integration (section 4).
5. Replace `fzf` usage in in-scope tools.

## 3. File explorer: yazi

Yazi is Rust, MIT, built on ratatui (same as the `ui` crate). Reuse in order:
1. Config and plugins only: theme generated from tokens, `pv` as previewer, Lua plugin swapping its built-in find/fzf for `pick`. Border shape stays as yazi hardcodes it.
2. Thin fork as a small patch series: replace yazi's drawing with `ui` widgets and tokens for real border control. Cost: rebasing on each upstream release, so keep patches few. Only for gaps left after step 1.
3. Decided: embed the `yazi-*` crates as a library for the files panel inside helix (section 4). No API stability, so pin versions and upgrade deliberately. Standalone yazi (steps 1-2) stays for use outside the editor.

TODO before step 2: read yazi's source to count how many files touch border and layout drawing.

## 4. Code editor: helix (fork)

No workarounds. Where helix lacks a feature, fork its source and integrate our tools natively.

- Fork helix. Keep the fork diff small: new code lives in our own crates (`ui`, `pick`, `pv`, `git-core`, files explorer, `git-panel`), and the helix patch is only glue.
- Pickers: replace `helix-term`'s picker component with `pick` as a library, drawn through `ui`.
- Files panel: new sidebar component in `helix-term`'s compositor, backed by the embedded `yazi-*` crates.
- Git panel: new sidebar component, backed by `git-panel` / `git-core`.
- Previews: `pv` as a library, in-process.
- Theme and borders: read from the tokens via `ui`, so helix follows the design.
- Read-only mode doubles as the docs viewer.
- Helix has no sidebar or panel system today, hence the fork.

## 5. Git status highlighting (cross-cutting)

- `pv`: highlights the changed rows of a file (added, modified, deleted) using the git status colors.
- `pick` in file mode and the files panel: highlight rows by file git status.
- On by default. A flag disables it (e.g. `--no-git`, with a matching config key).
- One shared Rust crate (`git-core`, on `gix` or `git2`) does repo discovery, per-file status and per-line diffs. `pv`, `pick`, the files panel and `git-panel` all use it, so git logic lives in one place.
- Status is computed once per repo and cached, not per keystroke, so large repos stay fast in the picker.
- Colors come from the tokens (see section 1).

## 6. Keyboard: kanata

Kanata stays standalone. On WSL2 a Linux kanata cannot see the Windows keyboard, so run `kanata.exe` on the Windows host with the same `.kbd` config generated from the dotfiles. The zellij layer pill reads layer changes from kanata's TCP port (check how `kanata-layer-indicator.nix` connects; from WSL reach the host via localhost forwarding or host IP).

## Overall build order

1. Tokens (Nix, JSON) and generated third-party themes.
2. Shared crates: `ui`, `git-core`.
3. `pv` (Rust), then `pick`.
4. yazi integration (previewer, finder, theme).
5. Helix fork: picker, files panel, git panel.
6. `git-panel` standalone binary; retire lazygit.
7. Retire fzf and neovim configs in scope (after confirming neovim).

## Working preferences

- Confirm the approach with the user before implementing; don't split files into several without being asked.
- Keep caution callouts short; the repo is git-tracked and reversible.
- Keep this plan file the single source of context; update it as decisions change.
