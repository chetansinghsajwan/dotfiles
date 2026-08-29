{ pkgs, lib, ... }:
let
  user = import ../../home/config/user.nix;
in
{
  dotfiles.features.gui = lib.mkForce false;
  dotfiles.system.extraGroups = [ "wheel" ];

  users.users.${user.username} = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "Chetan Singh Sajwan";
    extraGroups = [ "wheel" ];
  };
}
