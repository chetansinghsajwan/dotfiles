{ config, lib, ... }:
let
  enable =
    config.dotfiles.desktop.hyprland.enable && config.dotfiles.desktop.hyprland.shell == "caelestia";
in
{
  config = lib.mkIf enable {
    programs.caelestia = {
      enable = true;
      cli.enable = true;
    };

    wayland.windowManager.hyprland = {
      extraConfig = lib.mkAfter ''
        hl.bind(mod .. " + SPACE", hl.dsp.global("caelestia:launcher"))
      '';
    };
  };
}
