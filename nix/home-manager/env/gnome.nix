{ pkgs, ... }:
{
    gtk = {
        enable = true;
    };

    home.packages = with pkgs; [
        gnome.dconf-editor
        gnome.gnome-terminal
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

    programs.gnome-terminal = {
        enable = true;
        showMenubar = false;

        profile."b1dcc9dd-5262-4d8d-a863-c897e6d979b9" = {
            visibleName = "default";
            default = false;
        };

        profile."1f9b272d-225c-474f-9e70-326fa579639d" = {
            visibleName = "custom";
            default = true;
            cursorShape = "ibeam";
            font = "Monospace 13";
        };
    };

    dconf.settings = {
        "org/gnome/shell" = {
            favorite-apps = [];
            disable-user-extensions = false;
            enabled-extensions = [
                "gsconnect@andyholmes.github.io"
                "blur-my-shell@aunetx"
                "user-theme@gnome-shell-extensions.gcampax.github.com"
                "Vitals@CoreCoding.com"
                "sound-output-device-chooser@kgshank.net"
            ];
        };

        "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
            enable-hot-corners = false;
        };

        "org/gnome/desktop/peripherals/touchpad" = {
            tap-to-click = true;
            two-finger-scrolling-enabled = true;
        };

        "org/gnome/desktop/background" = {
            # picture-uri = "file://../../wallpapers/gnome-default-light.png";
            # picture-uri-dark = "file://../../wallpapers/gnome-default-dark.png";
        };
    };
}