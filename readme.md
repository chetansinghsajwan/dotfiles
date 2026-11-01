# dotfiles

Personal Nix flake configuration for all my machines: NixOS, nix-darwin, and
standalone Home Manager, unified under a single `dotfiles.*` option namespace.

## TODO

- Make the quick panel (panel that appears after leader key) appear in center
  (like a popup).
- Add commands in help section (?) for every tool. For example, the commands available inside git
  panel in helix are not present anywhere to refer to.
- In every movement area, hjkl is for left, down, up, right. and ctrl modifier increases the
  movement extent to 5 lines. This should work in the files space as well as editor space.
  In typing space, ctrl + hl should jump by words but should consider EOL as a stop point as well.
- The files pane in helix should follow the opened file.
- Takeover the helix symbols pane as well, to keep the design and experience consistent.
- In helix, add cmd to close all other tabs.
- In files SPACE, add cmd to show/hide hidden dir/files.
- In files SPACE, add cmd to respect ignore files to hide those entries. Should we add a marker
  somewhere showing that the some files are hidden?
- In files SPACE, when a file is deleted or trashed but was open in a buffer, close that buffer as
  well.
- In files SPACE, change delete op to d -> d (again to confirm, instead of yes)
- In quick SPACE, when a key is pressed which is not linked to any command, show a warning.
- In helix, add a separator between tabs and the editor
- In helix, can we remove the bottom most (below the ribbon) space?
- Can gu identify git space changes?
- Can helix identify git space changes?
- Can helix identify file changes on disk?
- Build nu with mac support enabled by default on darwin builds.
- In files SPACE, pressing "/" should trigger a search in the current dir (not sub dir), what
  should we do for sub dir searching?
- Files Tool
  - Add leader -> c -> f to focus on the current dir, or maybe remove
    the heirarchy style itself?

- Helix
  - Open next, prev tab operations
  - Add markdown preview
  - Add format command
  - Add command to switch tab size

- pv tool
  - Add markdown preview (default)

## Machines

| Flake output                          | Host                    | System           |
| ------------------------------------- | ----------------------- | ---------------- |
| `nixosConfigurations.nixos`           | `hosts/nixos`           | `x86_64-linux`   |
| `nixosConfigurations.wsl`             | `hosts/wsl`             | `x86_64-linux`   |
| `darwinConfigurations.macbook-air-m3` | `hosts/macbook-air-m3`  | `aarch64-darwin` |
| `homeConfigurations.chetan`           | standalone Home Manager | `x86_64-linux`   |

## Layout

```
.
├── flake.nix              flake entry point, wires inputs to hosts
├── config/                shared `dotfiles.*` options (user, theme, fonts, features)
├── hosts/
│   ├── shared.nix          settings common to all NixOS/darwin hosts
│   ├── nixos/              NixOS desktop (Hyprland, kanata keyboard remapping)
│   ├── wsl/                NixOS on WSL
│   └── macbook-air-m3/     nix-darwin
├── home/
│   ├── home.nix             Home Manager entry point
│   └── modules/
│       ├── programs/        one file per program (git, zsh, helix, starship, ...)
│       ├── features/         optional bundles: dev, gui, gaming
│       └── desktop/          desktop-environment modules (gnome, hyprland)
├── lib/                    shared helper functions
└── treefmt.nix             formatter/linter config (nixfmt, statix, deadnix)
```

## Usage

Apply a configuration on the machine it targets:

```sh
# NixOS (nixos)
sudo nixos-rebuild switch --flake .#nixos

# NixOS (WSL)
sudo nixos-rebuild switch --flake .#wsl

# nix-darwin
sudo darwin-rebuild switch --flake .#macbook-air-m3

# Standalone Home Manager (non-NixOS/non-darwin Linux)
home-manager switch --flake .#chetan
```

## Development

```sh
nix flake check   # evaluate all outputs + run formatter check
nix fmt           # format the repo with nixfmt (via treefmt)
nix develop       # shell with nixfmt, statix, deadnix, nil, nixd on PATH
```

See `agents.md` for conventions to follow when editing this repo.
