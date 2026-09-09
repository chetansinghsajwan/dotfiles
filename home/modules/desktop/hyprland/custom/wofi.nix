{ config, lib, ... }:
let
  enable = config.dotfiles.desktop.hyprland.enable && config.dotfiles.desktop.hyprland.shell == "custom";
in
{
  config = lib.mkIf enable {
    programs.wofi = {
      settings = {
        width = 600;
        height = 400;
        location = "center";
        show = "drun";
        prompt = "Search apps...";
        filtger_rate = 100;
        allow_markup = true;
        no_actions = true;
        halign = "fill";
        orientation = "vertical";
        content_halign = "fill";
        insensitive = true;
        allow_images = true;
        image_size = 32;
        gtk_dark = true;
        dynamic_lines = true;
        hide_scroll = true;
      };

      style = ''
        * {
          font-family: "${config.stylix.fonts.sansSerif.name}";
          font-size: 14px;
        }

        window {
          border-radius: 12px;
          border: 2px solid @base0D;
        }

        #input {
          margin: 8px;
          padding: 8px;
          border-radius: 8px;
          border: none;
        }

        #inner-box {
          margin: 4px;
        }

        #outer-box {
          margin: 4px;
          padding: 4px;
        }

        #entry {
          padding: 8px;
          border-radius: 8px;
        }

        #entry:selected {
          background-color: @base0D;
        }

        #entry:selected #text {
          color: @base00;
        }

        #text {
          margin: 4px;
        }
      '';
    };
  };
}