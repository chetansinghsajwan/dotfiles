# This repo's own default (ayu-dark, config/default.nix's
# dotfiles.theme.name default) base16 palette - module.nix's `colors`
# option defaults to this, so a standalone build is themed out of the box
# without needing Stylix at all. home-manager overrides it with the live
# Stylix palette when present (see flake.nix's `homeModules.default`).
{
  base00 = "#0b0e14";
  base01 = "#131721";
  base02 = "#202229";
  base03 = "#3e4b59";
  base04 = "#bfbdb6";
  base05 = "#e6e1cf";
  base06 = "#ece8db";
  base07 = "#f2f0e7";
  cyan = "#95e6cb";
  green = "#aad94c";
  magenta = "#d2a6ff";
  yellow = "#ffb454";
  red = "#f07178";
  blue = "#59c2ff";
  brown = "#e6b450";
  orange = "#ff8f40";
}
