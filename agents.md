# AGENTS.md

Guidance for AI coding agents working in this repository.

## What this is

A personal, multi-host Nix flake configuration covering NixOS, nix-darwin, and
standalone Home Manager. It configures three machines:

- `hosts/nixos` — NixOS desktop
- `hosts/wsl` — NixOS on WSL
- `hosts/macbook-air-m3` — nix-darwin
- `homeConfigurations."chetan"` — standalone Home Manager (any Linux machine)

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
- `pkgs/<name>/flake.nix` — one flake per program (git, zsh, helix, starship,
  vlc, etc.), each exposing a `homeModules.default` Home Manager module (and,
  for programs wrapped via nix-wrapper-modules, a `packages.default`). Wired
  into `flake.nix` as a `path:./pkgs/<name>` input and imported directly in
  `home/home.nix` — no per-program file lives under `home/` anymore.
- `home/modules/features/*.nix` — optional feature bundles gated by
  `config.dotfiles.features.*` (dev, gui, gaming).
- `home/modules/desktop/{gnome,hyprland}` — desktop-environment-specific
  modules.
- `lib/default.nix` — shared helper functions (`localLib`).
- `treefmt.nix` — formatter/linter config (nixfmt, statix, deadnix).

## Conventions

- Every module follows the standard `{ config, lib, pkgs, ... }:` module
  pattern and returns an attrset (options and/or config).
- New user-facing settings go through `options.dotfiles.*` in
  `config/default.nix`, then are read via `config.dotfiles.*` elsewhere.
- Keep program configs isolated: one flake per program under `pkgs/<name>/`,
  imported directly in `home/home.nix`.
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
