{ lib, isLinux ? false, ... }:
{
  imports = [ ../programs/zsh.nix ]
  ++ lib.optionals isLinux [
    ../programs/ghostty.nix
    ../programs/gnome-terminal.nix
  ];
}
