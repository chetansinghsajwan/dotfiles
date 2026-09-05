{
  config,
  pkgs,
  lib,
  ...
}:
let
  enableGnome = config.dotfiles.desktop.gnome.enable;
in
{
  imports = [
    ./keybindings.nix
  ];

  config = lib.mkIf enableGnome {

    dotfiles.programs = {
      gnome-terminal.enable = true;
      gnome-text-editor.enable = true;
      dconf-editor.enable = true;
      epiphany.enable = true;
    };

    gtk = {
      enable = true;
    };

    home.packages = with pkgs; [
      amberol # music app
      evince # document viewer
      loupe # image viewer
      snapshot # camera
      baobab # disk usage analyzer
      apostrophe # markdown editor
      nautilus # file explorer
      curtail # image compressor
      file-roller # ?
      gnome-connections
      gnome-sound-recorder
      gnome-logs
      gnome-shell
      gnome-music
      gnome-maps
      gnome-system-monitor
      gnome-weather
      gnome-tweaks
      gnome-contacts
      gnome-clocks
      gnome-autoar
      gnome-session
      gnome-calendar
      gnome-bluetooth
      gnome-screenshot
      gnome-calculator
      gnome-font-viewer
      gnome-disk-utility
      gnome-boxes
      # gnome-extension-manager

      gnomeExtensions.gsconnect
      gnomeExtensions.blur-my-shell
      gnomeExtensions.user-themes
      gnomeExtensions.vitals
      gnomeExtensions.fuzzy-app-search

      # for gsconnect
      openssl
    ];

    dconf.settings."org/gnome" = {
      "shell/favorite-apps" = [ ];
      "shell/disable-user-extensions" = false;
      "shell/enabled-extensions" = [
        "gsconnect@andyholmes.github.io"
        "blur-my-shell@aunetx"
        "user-theme@gnome-shell-extensions.gcampax.github.com"
        "Vitals@CoreCoding.com"
        "sound-output-device-chooser@kgshank.net"
        "gnome-fuzzy-app-search@gnome-shell-extensions.Czarlie.gitlab.com"
      ];

      "shell/app-switcher/current-workspace-only" = true;
      "mutter/dynamic-workspaces" = true;
      "mutter/edge-tiling" = true;

      "desktop/interface/color-scheme" = "prefer-dark";
      "desktop/interface/enable-hot-corners" = false;
      "desktop/interface/show-battery-percentage" = true;

      "desktop/peripherals/touchpad/tap-to-click" = true;
      "desktop/peripherals/touchpad/two-finger-scrolling-enabled" = true;
    };
  };
}
