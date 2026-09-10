{ config, lib, ... }:
let
  enable =
    config.dotfiles.desktop.hyprland.enable && config.dotfiles.desktop.hyprland.shell == "custom";
  wallpaper = config.dotfiles.theme.wallpaper;
in
{
  config = lib.mkIf enable {
    services.hyprpaper = {
      settings = {
        preload = [ wallpaper ];
        wallpaper = [ ",${wallpaper}" ];
      };
    };
  };
}
