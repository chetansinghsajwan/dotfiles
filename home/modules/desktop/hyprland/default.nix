{ config, pkgs, lib, ... }:
let
  enable = config.dotfiles.desktop.hyprland.enable;
in
{
  imports = [
    ./custom
    ./caelestia
  ];

  config = lib.mkIf enable {
    home.packages = with pkgs; [
      brightnessctl
    ];

    wayland.windowManager.hyprland = {
      enable = true;
      configType = "lua";
      extraConfig = builtins.readFile ./hyprland.lua;
    };
  };
}
