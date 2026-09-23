# Shared helpers for the wrapped-package flakes under pkgs/ (helix, btop,
# lazygit, zellij, fzf, yazi). These can't be shared as a flake input
# between pkgs/<name> flakes themselves - a `path:./pkgs/<name>` input is
# copied as only that subtree, so `path:../lib`-style sibling references
# don't resolve. Instead each mk<Name> takes the relevant helper(s) as a
# plain parameter, and the home-manager module (which already has
# localLib in scope) passes them in from here.
{ lib }:
{
  base16 = import ./base16.nix { inherit lib; };
  kdl = import ./kdl.nix { inherit lib; };
  cliFlags = import ./cli-flags.nix { inherit lib; };
}
