let profile-custom = "1f9b272d-225c-474f-9e70-326fa579639d";
    profile-default = "b1dcc9dd-5262-4d8d-a863-c897e6d979b9";
in
{ pkgs, lib, ... }:
{
    home.packages = [ pkgs.gnome.gnome-terminal ];

    dconf.settings = {
        "org/gnome/terminal/legacy" = {
            "default-show-menubar" = false;
        };

        "org/gnome/terminal/legacy/profiles:" = {
            default = profile-custom;
            list = [
                profile-custom
                profile-default
            ];
        };

        "org/gnome/terminal/legacy/profiles:/:${profile-custom}" = {
            "visible-name" = "custom";
            "audible-bell" = false;
            "backspace-binding" = "ascii-delete";
            "cursor-blink-mode" = "system";
            "cursor-shape" = "ibeam";
            "default-size-columns" = 120;
            "delete-binding" = "delete-sequence";
            "font" = "Monospace 14";
            "scroll-on-output" = true;
            "scrollback-lines" = 10000;
            "scrollbar-policy" = "always";
            "use-system-font" = false;
            "use-theme-colors" = true;
            "login-shell" = true;
            "use-custom-command" = true;
            "custom-command" = "zsh";
        };

        "org/gnome/terminal/legacy/profiles:/:${profile-default}" = {
            "visible-name" = "default";
        };
    };
}
