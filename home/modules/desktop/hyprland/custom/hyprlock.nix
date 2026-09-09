{ config, lib, ... }:
let
  enable = config.dotfiles.desktop.hyprland.enable && config.dotfiles.desktop.hyprland.shell == "custom";
in
{
  config = lib.mkIf enable {
    stylix.targets.hyprlock.enable = true;
    programs.hyprlock.enable = true;
  };
}
