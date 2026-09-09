{ config, lib, ... }:
let
  enable = config.dotfiles.desktop.hyprland.enable && config.dotfiles.desktop.hyprland.shell == "custom";
in
{
  config = lib.mkIf enable {
    programs.waybar = {
      settings = [
        {
          layer = "top";
          position = "top";
          height = 30;

          modules-left = [ "hyprland/workspaces" "hyprland/window" ];
          modules-center = [ "clock" ];
          modules-right = [ "pulseaudio" "backlight" "battery" "tray" ];

          "hyprland/workspaces" = {
            format = "{name}";
            format-icons = {
              active = "";
              default = "";
            };
          };

          "hyprland/window" = {
            format = "{}";
            max-length = 50;
            separate-outputs = true;
          };

          clock = {
            format = "{:%H:%M · %a %d %b}";
            tooltip-format = "{:%Y-%m-%d}";
          };

          pulseaudio = {
            format = "{icon} {volume}%";
            format-muted = "󰖁 {volume}%";
            format-icons = {
              headphone = "";
              hands-free = "";
              headset = "";
              phone = "";
              portable = "";
              car = "";
              default = [ "" "" "" ];
            };
            scroll-step = 1;
            on-click = "pavucontrol";
          };

          backlight = {
            format = "{icon} {percent}%";
            format-icons = [ "󰃞" "󰃟" "󰃠" ];
            scroll-step = 1;
          };

          battery = {
            format = "{icon} {capacity}%";
            format-charging = "󰂄 {capacity}%";
            format-icons = [ "󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" ];
          };

          tray = {
            icon-size = 18;
            spacing = 10;
          };
        }
      ];

      style = ''
        * {
          font-family: "${config.stylix.fonts.monospace.name}";
          font-size: 12pt;
        }

        window#waybar {
          background-color: alpha(@base00, 0.95);
          border-bottom: 2px solid @base0D;
          color: @base05;
          padding: 0 10px;
        }

        #workspaces button {
          padding: 0 8px;
          background-color: transparent;
          border: none;
          border-radius: 4px;
          margin: 0 2px;
        }

        #workspaces button.active {
          background-color: @base0D;
          color: @base00;
        }

        #workspaces button:hover {
          background-color: @base02;
        }

        #window {
          padding: 0 10px;
          color: @base08;
        }

        #clock, #pulseaudio, #backlight, #battery {
          padding: 0 10px;
        }

        #tray {
          padding: 0 5px;
        }
      '';
    };
  };
}