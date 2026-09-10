{ config, lib, ... }:
let
  enable =
    config.dotfiles.desktop.hyprland.enable && config.dotfiles.desktop.hyprland.shell == "caelestia";
in
{
  config = lib.mkIf enable {
    programs.kitty.enable = true;
    wayland.windowManager.hyprland = {
      enable = true;
      configType = "lua";

      settings = {
        config = {
          input = {
            touchpad.natural_scroll = true;
            natural_scroll = true;
          };

          general = {
            gaps_in = 6;
            gaps_out = 10;
          };

          decoration = {
            rounding = 14;
          };

          dwindle.preserve_split = true;
        };

        monitor = [
          {
            output = "";
            mode = "preferred";
            position = "auto";
            scale = 1;
          }
        ];
      };
    };

    programs.caelestia = {
      enable = true;
      cli.enable = true;
    };
  };
}
