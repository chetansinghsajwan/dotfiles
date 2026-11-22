# dotfiles

Personal Nix flake configuration for all my machines: NixOS, nix-darwin, and
standalone Home Manager, unified under a single `dotfiles.*` option namespace.
It also holds my terminal toolset: a few Rust tools and a helix fork that share one
design (the `pkgs/tuikit` and `pkgs/helix-improved` submodules).

## TODO

Open:

- nothing at the moment

## Machines

| Flake output                            | Host                    | System               |
| --------------------------------------- | ----------------------- | -------------------- |
| `nixosConfigurations.<system>.default`  | `hosts/nixos`           | Linux (per system)   |
| `nixosConfigurations.<system>.wsl`      | `hosts/nixos-wsl`       | Linux (per system)   |
| `darwinConfigurations.<system>.default` | `hosts/darwin`          | macOS (per system)   |
| `nixosConfigurations.jman-nixos`        | `hosts/jman-nixos`      | personal NixOS (WSL) |
| `nixosConfigurations.honor-m3-nixos`    | `hosts/honor-m3`        | Honor laptop         |
| `darwinConfigurations.macbook-air13`    | `hosts/macbook-air-13`  | MacBook Air          |
| `homeConfigurations.<system>.default`   | standalone Home Manager | any supported system |

## Layout

```text
.
├── flake.nix              flake entry point, wires inputs to hosts
├── config/                shared `dotfiles.*` options (user, theme, fonts, features)
├── hosts/                 one folder per machine plus `shared`, `nixos`, `nixos-wsl`, `darwin`
├── home/
│   ├── home.nix           Home Manager entry point
│   ├── programs/          one module per program (git, zsh, helix, zellij, ...)
│   ├── features/          optional bundles: dev, gui, gaming
│   ├── desktop/           desktop environments (gnome, hyprland)
│   ├── (the Rust tools and the helix fork are submodules under pkgs/)
│   └── stylix.nix         colors and fonts for everything
├── Taskfile.yml           tasks (fmt, check, test, scan)
└── .config/hk.pkl        formatters, linters and git hooks (hk)
```

## The terminal tools

One tool owns one domain, and the design (colors, keys, menus, previews) lives in the shared
`ui` crate. They run in a terminal on Linux, WSL and macOS.

| Tool       | What it does                                                                                                                                                          |
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pv`       | previews: text, Markdown, diffs, images, audio and video details, PDF text, CSV and spreadsheet tables, directories; `pv -` reads stdin, `pv --diff` is the git pager |
| `pick`     | fuzzy finder (files, buffers, symbols, live sources)                                                                                                                  |
| `files`    | file explorer (`f` changes directory on exit); `files list` (alias `ll`) prints a folder as a list                                                                    |
| `gu`       | git UI: Status (folder tree), Commits (graph, search, filters), Refs (tree, renames)                                                                                  |
| `nu`       | network and bluetooth                                                                                                                                                 |
| `mdexport` | Markdown to PDF (Typst, no other program): `mdexport file.md`, or `Space m e` in helix (asks for paper, fonts and size)                                               |
| helix fork | the editor, with docks that embed `files`, the git panel and the diagnostics panel                                                                                    |

Keys are the same everywhere: `space` opens Quick Keys, `space space` searches every action,
`?` lists the keys, `dd` confirms a delete. See `pkgs/tuikit/docs/usage-design.md`.

### Configuration

Each tool reads a TOML file, the shared `~/.config/ui/config.toml` first and then its own
`~/.config/<tool>/config.toml` (`gu`, `files`, `nu`, `hx-ui` for the helix docks),
which overrides it. `UI_CONFIG` and `UI_TOOL_CONFIG` name other files.

```toml
leader = "space"

[keys]                         # action id -> key(s); an empty list unbinds it
"nav.down" = ["j", "down"]
"change.stage" = "s"
"remote.push" = "leader r p"
```

The ids are the ones `space space` lists. The theme is `~/.config/ui/theme.json` (generated
from the stylix colors; `UI_THEME` names another).

## Usage

Apply the configuration of the machine you are on, with the binary cache on from the very first
build (works on a fresh NixOS, nix-darwin or Linux machine with Nix installed, and asks only for
the sudo password):

```sh
scripts/switch.sh [host]     # or `task switch -- [host]` inside the dev shell
```

The host is the one named like the machine, else the platform default.

Machine-local overrides go in `.config/options-local.nix` (git-ignored; a module such as
`{ dotfiles.theme.wallpaper = "/path/mine.png"; }`). A flake cannot see ignored files, so the
switch is impure and finds the file through `DOTFILES_ROOT`, which the script sets. By hand, add
`--impure` and `DOTFILES_ROOT=$PWD` (with `sudo env DOTFILES_ROOT=$PWD ...` for system switches):

```sh
# NixOS (WSL)
sudo nixos-rebuild switch --flake .#jman-nixos

# nix-darwin
sudo darwin-rebuild switch --flake .#macbook-air13

# Standalone Home Manager (non-NixOS/non-darwin Linux)
home-manager switch --flake .#chetan
```

## Development

```sh
nix develop       # shell with every tool the tasks and hooks use
task fmt          # format every file
task check        # format check and every linter
task test         # Rust tests and evaluation of every host

# the Rust tools: build and test without a full Nix build
cd pkgs/tuikit && nix shell nixpkgs#cargo nixpkgs#rustc nixpkgs#gcc -c cargo test
```

The look is described in `pkgs/tuikit/docs/ui-design.md`, the keys in `pkgs/tuikit/docs/usage-design.md`.

See `agents.md` for conventions to follow when editing this repo.
