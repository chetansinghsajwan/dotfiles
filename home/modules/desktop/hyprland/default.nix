{ config, pkgs, lib, ... }:
let
  enableHyprland = config.dotfiles.desktop.hyprland.enable;
in
{
  imports = [
    ./waybar.nix
    ./wofi.nix
    ./hyprpaper.nix
    ./hypridle.nix
    ./hyprlock.nix
  ];

  config = lib.mkIf enableHyprland {
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
      enable = true;
      configType = "hyprlang";
      settings = {
        "$mod" = "SUPER";
        "$alt" = "ALT";

        input = {
          touchpad = {
            natural_scroll = true;   # set true if you WANT inverted (natural/Mac-style)
          };
          natural_scroll = true;     # for mouse wheel
        };

        monitor = [ ",preferred,auto,1" ];

        exec-once = [
          "waybar"
          "hypridle"
        ];

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
          shadow = {
            enabled = true;
            range = 4;
            render_power = 3;
          };
        };

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

        dwindle = {
          # pseudotile = "yes";
          preserve_split = true;
        };

        # Keybindings
        bind = [
          # Apps
          "$mod, Return, exec, ${config.dotfiles.shell.program}"
          "$mod, C, exec, code"
          "$mod, E, exec, nautilus"
          "$mod, B, exec, firefox"

          # Window management
          "$mod, Q, killactive"
          "$mod, F, fullscreen"
          "$mod, V, togglefloating"

          # Focus
          "$mod, Left, movefocus, l"
          "$mod, Right, movefocus, r"
          "$mod, Up, movefocus, u"
          "$mod, Down, movefocus, d"

          # Move window
          "$mod $alt, Left, movewindow, l"
          "$mod $alt, Right, movewindow, r"
          "$mod $alt, Up, movewindow, u"
          "$mod $alt, Down, movewindow, d"

          # Workspaces
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

          # Move to workspace
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

          # Screenshot (grim + slurp)
          ", Print, exec, grim -g \"$(slurp)\" ~/pictures/screenshot-$(date +%s).png"
          "$shift, Print, exec, grim ~/pictures/screenshot-$(date +%s).png"

          # Search (wofi)
          "$mod, D, exec, wofi --show drun"
        ];

        binde = [
          # Resize (hold, don't repeat)
          "$mod $alt, L, resizeactive, 30 0"
          "$mod $alt, H, resizeactive, -30 0"
          "$mod $alt, K, resizeactive, 0 -30"
          "$mod $alt, J, resizeactive, 0 30"
        ];

        bindl = [
          # Volume (media keys, no repeat)
          ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
          ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
          ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"

          # Brightness
          ", XF86MonBrightnessUp, exec, brightnessctl set +5%"
          ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
        ];

        mouse_modify = "$mod";
        bindm = [
          "$mod, mouse:272, movewindow"
          "$mod, mouse:273, resizewindow"
        ];
      };
    };
  };
}