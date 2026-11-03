# dotfiles

Personal Nix flake configuration for all my machines: NixOS, nix-darwin, and
standalone Home Manager, unified under a single `dotfiles.*` option namespace.
It also holds my terminal toolset: a few Rust tools and a helix fork that share one
design (`home/crates`).

## TODO

Open:

- nothing at the moment

## Machines

| Flake output                                  | Host                     | System                   |
| --------------------------------------------- | ------------------------ | ------------------------ |
| `nixosConfigurations.<system>.default`        | `hosts/nixos`            | Linux (per system)       |
| `nixosConfigurations.<system>.wsl`            | `hosts/nixos-wsl`        | Linux (per system)       |
| `darwinConfigurations.<system>.default`       | `hosts/darwin`           | macOS (per system)       |
| `nixosConfigurations.jman-nixos`              | `hosts/jman-nixos`       | personal NixOS (WSL)     |
| `nixosConfigurations.honor-m3-nixos`          | `hosts/honor-m3`         | Honor laptop             |
| `darwinConfigurations.macbook-air13`          | `hosts/macbook-air-13`   | MacBook Air              |
| `homeConfigurations.<system>.default`         | standalone Home Manager  | any supported system     |

## Layout

```
.
├── flake.nix              flake entry point, wires inputs to hosts
├── config/                shared `dotfiles.*` options (user, theme, fonts, features)
├── hosts/                 one folder per machine plus `shared`, `nixos`, `nixos-wsl`, `darwin`
├── home/
│   ├── home.nix           Home Manager entry point
│   ├── programs/          one module per program (git, zsh, helix, zellij, ...)
│   ├── features/          optional bundles: dev, gui, gaming
│   ├── desktop/           desktop environments (gnome, hyprland)
│   ├── crates/            the Rust tools (workspace, built with crane)
│   ├── helix/             the helix fork, `helix-fork.nix` builds it
│   └── stylix.nix         colors and fonts for everything
├── docs/usage-design.md   how the tools are used: keys, menus, shared verbs
├── plan.md                the plan and decisions for the terminal toolset
└── treefmt.nix            formatter/linter config (nixfmt, statix, deadnix)
```

## The terminal tools

One tool owns one domain, and the design (colors, keys, menus, previews) lives in the shared
`ui` crate. They run in a terminal on Linux, WSL and macOS.

| Tool        | What it does                                                                          |
| ----------- | ------------------------------------------------------------------------------------- |
| `pv`        | previews: text, Markdown, diffs, images, audio and video details, directories         |
| `pick`      | fuzzy finder (files, buffers, symbols, live sources)                                  |
| `files`     | file explorer                                                                         |
| `gu`        | git UI: Status (folder tree), Commits (graph, search, filters), Refs (tree, renames)  |
| `nu`        | network and bluetooth                                                                 |
| `mdexport`  | Markdown to PDF (Typst, no other program): `mdexport file.md` or `Space m e` in helix |
| helix fork  | the editor, with docks that embed `files`, the git panel and the diagnostics panel    |

Keys are the same everywhere: `space` opens Quick Keys, `space space` searches every action,
`?` lists the keys, `dd` confirms a delete. See `docs/usage-design.md`.

### Configuration

Each tool reads a TOML file, the shared `~/.config/ui/config.toml` first and then its own
`~/.config/<tool>/config.toml` (`gu`, `files`, `nu`, `git-panel`, `hx-ui` for the helix docks),
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

Apply a configuration on the machine it targets:

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
nix flake check   # evaluate all outputs + run formatter check
nix fmt           # format the repo with nixfmt (via treefmt)
nix develop       # shell with nixfmt, statix, deadnix, nil, nixd on PATH

# the Rust tools: build and test without a full Nix build
cd home/crates && nix shell nixpkgs#cargo nixpkgs#rustc nixpkgs#gcc -c cargo test
```

See `agents.md` for conventions to follow when editing this repo.
