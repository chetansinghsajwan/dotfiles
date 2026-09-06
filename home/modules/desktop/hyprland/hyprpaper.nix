{ config, ... }:
let
  wallpaper = config.dotfiles.theme.wallpaper;
in
{
  services.hyprpaper = {
    settings = {
      preload = [ wallpaper ];
      wallpaper = [ ",${wallpaper}" ];
    };
  };
}