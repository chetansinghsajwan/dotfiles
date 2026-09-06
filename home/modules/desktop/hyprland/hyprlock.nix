{ config, lib, ... }:
let
  enableHyprland = config.dotfiles.desktop.hyprland.enable;
in
{
  config = lib.mkIf enableHyprland {
    stylix.targets.hyprlock.enable = true;
    programs.hyprlock.enable = true;
  };
}
