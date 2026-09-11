{
  config,
  pkgs,
  lib,
  ...
}:
let
  enable = config.dotfiles.desktop.hyprland.enable;
  defaultTerminal = config.dotfiles.terminal.default;
  hyprlandConfig = lib.replaceStrings [ "__DEFAULT_TERMINAL__" ] [ defaultTerminal ] (
    builtins.readFile ./hyprland.lua
  );
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
      extraConfig = lib.mkBefore hyprlandConfig;
    };
  };
}
