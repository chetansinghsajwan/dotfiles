{ pkgs, ... }:
{
    gtk = {
        enable = true;
    };

    imports = [
        ./keybindings.nix
        ../../packages/gnome-terminal.nix
        ../../packages/gnome-text-editor.nix
        ../../packages/epiphany.nix
        ../../packages/dconf-editor.nix
    ];

    home.packages = with pkgs; [
        amberol # music app
        evince # document viewer
        loupe # image viewer
        snapshot # camera
        baobab # disk usage analyzer
        apostrophe # markdown editor
        gnome-connections
        gnome.gnome-sound-recorder
        gnome.nautilus
        gnome.gnome-logs
        gnome.gnome-shell
        gnome.file-roller
        gnome.gnome-music
        gnome.gnome-maps
        gnome.gnome-system-monitor
        gnome.gnome-weather
        gnome.gnome-tweaks
        gnome.gnome-contacts
        gnome.gnome-clocks
        gnome.gnome-autoar
        gnome.gnome-session
        gnome.gnome-nettool
        gnome.gnome-calendar
        gnome.gnome-bluetooth
        gnome.gnome-screenshot
        gnome.gnome-calculator
        gnome.gnome-font-viewer
        gnome.gnome-disk-utility
        gnome.gnome-boxes
        gnome-extension-manager

        gnomeExtensions.gsconnect
        gnomeExtensions.blur-my-shell
        gnomeExtensions.user-themes
        gnomeExtensions.vitals
        gnomeExtensions.sound-output-device-chooser

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
