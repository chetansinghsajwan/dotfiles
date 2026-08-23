# dotfiles

Nix-based host and Home Manager configs for:

- `hosts/workstation` — NixOS desktop
- `hosts/macbook-air-m3` — nix-darwin laptop
- `home/` — shared Home Manager modules and per-user config

## Layout

- `flake.nix` wires the NixOS and Darwin hosts.
- `home/config/` holds shared user, theme, and preference defaults.
- `home/modules/features/` toggles feature groups like dev, GUI, and gaming.
- `home/modules/programs/` contains app and shell modules.
- `hosts/*/configuration.nix` keeps system-specific NixOS/Darwin settings.

## Notes

- Linux and Darwin Home Manager configs both reuse `home/home.nix`.
- Shared identity settings live in `home/config/user.nix`.
- The workstation host is split into `hardware-configuration.nix`, `kanata.nix`, `system.nix`, and `user.nix`.

## Keyboard

`hosts/workstation/kanata.kbd` defines the custom layer-based layout.
