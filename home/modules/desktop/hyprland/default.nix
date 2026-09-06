{ config, pkgs, lib, ... }:
let
  enableHyprland = config.dotfiles.desktop.hyprland.enable;
in
{
  config = lib.mkIf enableHyprland {
    wayland.windowManager.hyprland = {
      enable = true;
      settings = {
        "$mod" = "SUPER";
        monitor = [ ",preferred,auto,1" ];

        exec-once = [
          "waybar"
          "hypridle"
        ];

        bind = [
          "$mod, Return, exec, ${config.dotfiles.shell.program}"
          "$mod, Q, killactive"
          "$mod, F, fullscreen"
          "$mod, D, exec, wofi --show drun"
        ];
      };
    };

    programs.waybar.enable = true;
    programs.wofi.enable = true;

    services.hyprpaper.enable = true;
    services.hypridle.enable = true;

    home.packages = with pkgs; [
      hyprlock
      grim
      slurp
      wl-clipboard
    ];

    stylix.targets.hyprland.enable = true;
    stylix.targets.waybar.enable = true;
    stylix.targets.wofi.enable = true;
  };
}