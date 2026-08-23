{ pkgs, ... }:
let
  user = import ../../home/config/user.nix;
in
{
  users.users.${user.username} = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "Chetan Singh Sajwan";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = [ ];
  };
}
