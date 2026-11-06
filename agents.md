# AGENTS.md

Guidance for AI coding agents working in this repository.

## Ongoing work

Read `pkgs/tuikit/plan.md` first: it holds the full context, decisions and open questions
for the terminal toolset standardization (shared TUI design, `pv`, `pick`,
helix fork, git panel).

## What this is

A personal, multi-host Nix flake configuration covering NixOS, nix-darwin, and
standalone Home Manager (hosts are listed in `readme.md`), plus the Rust terminal
toolset and a helix fork in `pkgs/`.

## Layout

- `flake.nix` — entry point; wires inputs to `nixosConfigurations`,
  `darwinConfigurations`, and `homeConfigurations`.
- `config/default.nix` — defines the custom `dotfiles.*` option namespace
  (user info, theme, fonts, feature flags, shell, desktop) used across hosts
  and home-manager modules. Prefer adding new tunables here rather than
  hardcoding values in modules.
- `hosts/<name>/` — per-host `default.nix` (flake-level wiring),
  `configuration.nix` (system config), plus host-specific extras
  (e.g. `hardware-configuration.nix`, `kanata.nix`).
- `hosts/shared.nix` — settings common to all NixOS/darwin hosts.
- `home/home.nix` — Home Manager entry point.
- `home/programs/*.nix` — one file (or folder) per program (git, zsh, helix,
  zellij, etc.), each a self-contained Home Manager module.
- `home/features/*.nix` — optional feature bundles gated by
  `config.dotfiles.features.*` (dev, gui, gaming).
- `home/desktop/{gnome,hyprland}` — desktop-environment-specific modules.
- `pkgs/tuikit/` — git submodule (github.com/chetansinghsajwan/tuikit): the toolkit and the tools, one Cargo workspace and one flake (crane, shared dependency build); `pkgs/flake.nix` re-exports its tools and the editor. `pkgs/tuikit/crates/` holds the libraries (`ui`: shared design: theme, keys, config, lists, prompts; `pv`, `pick`, `files`, `git-core`, `git-panel`, `tb`, `diagnostics-panel`, `symbols-panel`); the tools in `pkgs/tuikit/tools/` are `pick`, `pv`, `files`, `tb`, `gu`, `nu` (with `core/`), `mdexport` (Markdown to PDF through Typst).
- `pkgs/helix-improved/` — git submodule (github.com/chetansinghsajwan/helix-improved): the helix fork (its own workspace, tuikit as a nested submodule), built by its own flake.
- The root `flake.nix` sets `inputs.self.submodules = true`, so Nix sees `pkgs/tuikit` and `pkgs/helix-improved` without any URL flag. Clone with `--recurse-submodules` (or run `git submodule update --init --recursive`).
- `pkgs/tuikit/docs/ui-design.md` — the look every tool follows (colors, chrome, layout, components); `pkgs/tuikit/docs/usage-design.md` — the keys and menus.
- `lib/default.nix` — shared helper functions (`llib`).
- `treefmt.nix` — formatter/linter config (nixfmt, statix, deadnix).

## Conventions

- Every module follows the standard `{ config, lib, pkgs, ... }:` module
  pattern and returns an attrset (options and/or config).
- New user-facing settings go through `options.dotfiles.*` in
  `config/default.nix`, then are read via `config.dotfiles.*` elsewhere.
- Keep program configs isolated: one file per program under
  `home/programs/`, imported from `home/home.nix` or a feature file.
- Don't hardcode the username/email/paths — use `config.dotfiles.user.*`.

## Building & validating changes

Run these from the repo root before considering a change done:

```sh
nix flake check                 # runs the formatter check + evaluates all outputs
nix fmt                         # auto-format with nixfmt via treefmt
nix develop                     # drops into a shell with nixfmt, statix, deadnix, nil, nixd
```

To evaluate/build a specific host without switching:

```sh
nix build .#nixosConfigurations.nixos.config.system.build.toplevel
nix build .#nixosConfigurations.wsl.config.system.build.toplevel
nix build .#darwinConfigurations.macbook-air-m3.system
nix build .#homeConfigurations.chetan.activationPackage
```

Never run `nixos-rebuild switch`, `darwin-rebuild switch`, or
`home-manager switch` against the live system unless explicitly asked — these
mutate the actual machine.

## Style

- Format with `nixfmt` (via `nix fmt`); don't hand-format Nix files.
- Fix `statix`/`deadnix` warnings surfaced by `nix flake check`.
- Keep diffs minimal and scoped to the host/module being changed.

## The Rust tools (`pkgs`)

- Design lives in one place: colors, keys, menus, lists, prompts and previews come from
  `ui` and `pv`; don't restyle in a tool.
  Structure and drawing of an element (a file or tree row, a list, a pane) is the toolkit.s
  job: the tool passes the content and enables the optional parts it needs (git markers, entry
  counts, `+n -n` counts, size and time columns). Never draw such an element locally; add or
  extend the component in `pkgs/tuikit/crates/ui`.
  Aligned columns are always separated by at least 1 blank cell (the toolkit's default), also in the tightest case; the name or text gives way first.
  The name is what shrinks (`…`) when a row is too narrow; the columns, counts and signs beside it
  keep their place (`ui::list::fit`, built into `ui::tree::file_row`).
- If it is unclear whether a piece of logic belongs to the toolkit or to a tool, ask before implementing. Derived presentation (the active guide scope, alignment, truncation, pinned ancestors) is the toolkit's: a tool passes content and cursor state and calls nothing extra.
- Hidden (dot) files show by default; files that git ignores do not (`I` shows them in `files`). Actions are registered in the tool's `keys.rs`
  with an id, a name, a description and default keys (`ui::keys`); users rebind them in TOML
  (`ui::config`, see `readme.md`). Follow `pkgs/tuikit/docs/usage-design.md` when adding a key.
- Git reads through `git-core` (gix) and writes through the `git` CLI; no tool shells out
  to git itself.
- Test and build with cargo, not a full Nix build:
  `cd pkgs && nix shell nixpkgs#cargo nixpkgs#rustc nixpkgs#gcc -c cargo test --workspace -j3`
  (use `nice` and `-j3`). The helix fork needs `HELIX_DISABLE_AUTO_GRAMMAR_BUILD=1`.
  Run the full `nix build` only when Nix files, lockfiles or dependencies change.
- Keep `pkgs/tuikit/plan.md` up to date after a change: it is the one context file for this work.
