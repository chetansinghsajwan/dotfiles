# dotfiles

Personal Nix flake configuration for all my machines: NixOS, nix-darwin, and
standalone Home Manager, unified under a single `dotfiles.*` option namespace.

## TODO

Open:

- In gu, when filtering, show the available options. for example, when filtering by author,
  show avaliable authors.
- In gu, use d for discard, r for rename or reword, s to stage/unstage, a to stage/unstage all.
- In gu, add a cmd to "switch to", which then provides the list of branches to switch to or a
  commit hash.
- In helix, provide 3 rendering modes for markdown. preview mode, is read only and previews the
  markdown. live mode, previews all the elements on which the cursor is not there. source mode
  just shows the raw source markdown.
- Improve pv by adding diff support like delta.
- Add support for images in pv
- Add support for audio files, videos in pv.
- Use d again after pressing d, to count as confirmation to delete
- In gu refs heirarchy, allow operations like rename and delete on the parent, so that it affects
  all the childs.
- In gu, do a little commit message (first line) highlighting the standard syntax category.
  For example, update: some message. highlight update: here.
- In gu status page, use heirarchy view by default and give the option to switch to list view.

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
