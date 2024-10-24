{ pkgs, ... }:
{
    gtk = {
        enable = true;
    };

    imports = [
        ./keybindings.nix
        ../../packages/gnome-terminal.nix
        ../../packages/gnome-text-editor.nix
        ../../packages/dconf-editor.nix
    ];

    home.packages = with pkgs; [
        amberol # music app
        evince # document viewer
        loupe # image viewer
        snapshot # camera
        baobab # disk usage analyzer
        apostrophe # markdown editor
        nautilus # file explorer
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
        gnome-nettool
        gnome-calendar
        gnome-bluetooth
        gnome-screenshot
        gnome-calculator
        gnome-font-viewer
        gnome-disk-utility
        gnome-boxes
        gnome-extension-manager

        gnomeExtensions.gsconnect
        gnomeExtensions.blur-my-shell
        gnomeExtensions.user-themes
        gnomeExtensions.vitals
        gnomeExtensions.sound-output-device-chooser
	    gnomeExtensions.fuzzy-app-search

        # for gsconnect
        openssl
    ];

    dconf.settings."org/gnome" =
    let
        wallpapers = pkgs.fetchFromGitHub {
            name = "wallpapers";
            owner = "shifu-dev";
            repo = "wallpapers";
            rev = "dev";
            hash = "sha256-52j39DIAFTAO6QG1YGX1OpuVSUPOqgfh/V8AYelHYYU=";
        };
    in
    {
        "shell/favorite-apps" = [];
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

        "desktop/background/picture-uri" = "file://${wallpapers}/white-fox.png";
        "desktop/background/picture-uri-dark" = "file://${wallpapers}/white-fox.png";
    };
}
