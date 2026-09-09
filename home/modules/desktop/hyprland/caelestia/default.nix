{ config, lib, ... }:
let
  enable = config.dotfiles.desktop.hyprland.enable && config.dotfiles.desktop.hyprland.shell == "caelestia";
in
{
  config = lib.mkIf enable {
    # Without this, Home Manager never manages Hyprland at all, so the
    # compositor falls back to its built-in default config (no keybinds,
    # no monitor setup) and the caelestia-shell systemd service never
    # starts (it waits for the Hyprland-managed session target).
    wayland.windowManager.hyprland = {
      enable = true;
      configType = "hyprlang";
      settings = {
        "$mod" = "SUPER";
        "$alt" = "ALT";

        input = {
          touchpad.natural_scroll = true;
          natural_scroll = true;
        };

        monitor = [ ",preferred,auto,1" ];

        general = {
          gaps_in = 8;
          gaps_out = 12;
          border_size = 2;
          layout = "dwindle";
        };

        decoration = {
          rounding = 8;
          blur = {
            enabled = true;
            size = 3;
            passes = 2;
          };
        };

        dwindle.preserve_split = true;

        bind = [
          "$mod, Return, exec, ${config.dotfiles.shell.program}"
          "$mod, Q, killactive"
          "$mod, F, fullscreen"
          "$mod, V, togglefloating"

          "$mod, Left, movefocus, l"
          "$mod, Right, movefocus, r"
          "$mod, Up, movefocus, u"
          "$mod, Down, movefocus, d"

          "$mod, 1, workspace, 1"
          "$mod, 2, workspace, 2"
          "$mod, 3, workspace, 3"
          "$mod, 4, workspace, 4"
          "$mod, 5, workspace, 5"
          "$mod, 6, workspace, 6"
          "$mod, 7, workspace, 7"
          "$mod, 8, workspace, 8"
          "$mod, 9, workspace, 9"
          "$mod, 0, workspace, 10"

          "$mod $alt, 1, movetoworkspace, 1"
          "$mod $alt, 2, movetoworkspace, 2"
          "$mod $alt, 3, movetoworkspace, 3"
          "$mod $alt, 4, movetoworkspace, 4"
          "$mod $alt, 5, movetoworkspace, 5"
          "$mod $alt, 6, movetoworkspace, 6"
          "$mod $alt, 7, movetoworkspace, 7"
          "$mod $alt, 8, movetoworkspace, 8"
          "$mod $alt, 9, movetoworkspace, 9"
          "$mod $alt, 0, movetoworkspace, 10"
        ];

        bindm = [
          "$mod, mouse:272, movewindow"
          "$mod, mouse:273, resizewindow"
        ];
      };
    };

    programs.caelestia = {
      enable = true;
      # Started via the systemd service, gated on Hyprland's session target
      # (see wayland.windowManager.hyprland.systemd above).
      # cli.enable = true;
    };
  };
}
