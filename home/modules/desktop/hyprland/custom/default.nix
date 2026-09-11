{
  config,
  pkgs,
  lib,
  ...
}:
let
  enable =
    config.dotfiles.desktop.hyprland.enable && config.dotfiles.desktop.hyprland.shell == "custom";
in
{
  imports = [
    ./waybar.nix
    ./wofi.nix
    ./hyprpaper.nix
    ./hypridle.nix
    ./hyprlock.nix
  ];

  config = lib.mkIf enable {
    programs.waybar.enable = true;
    programs.wofi.enable = true;
    programs.hyprlock.enable = true;

    services.hyprpaper.enable = true;
    services.hypridle.enable = true;

    home.packages = with pkgs; [
      grim
      slurp
      wl-clipboard
      brightnessctl
      wireplumber
    ];

    wayland.windowManager.hyprland = {
      settings = {
        exec-once = [
          "waybar"
          "hypridle"
        ];
        config = {
          animations = {
            enabled = true;
            bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
            animation = [
              "windows, 1, 7, myBezier"
              "windowsOut, 1, 7, default, popin 80%"
              "border, 1, 10, default"
              "fade, 1, 7, default"
              "workspaces, 1, 6, default"
            ];
          };
        };
      };
    };
  };
}
