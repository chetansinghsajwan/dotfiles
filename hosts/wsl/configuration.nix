{ lib, ... }:
{
  imports = [
    ../../config
    ../shared.nix
    ./system.nix
  ];

  dotfiles.features.gui = lib.mkForce false;
  dotfiles.desktop.gnome.enable = lib.mkForce false;
  dotfiles.system.isWsl = lib.mkForce true;
  dotfiles.system.extraGroups = [ "wheel" ];
}
