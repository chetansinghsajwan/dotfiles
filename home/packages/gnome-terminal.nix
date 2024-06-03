{ pkgs, lib, ... }:
{
    home.packages = with pkgs; [
        gnome.gnome-terminal
        cascadia-code
    ];

    fonts.fontconfig.enable = true;

    dconf.settings =
    let
        profileCustom = "1f9b272d-225c-474f-9e70-326fa579639d";
        profileDefault = "b1dcc9dd-5262-4d8d-a863-c897e6d979b9";
    in
    {
        "org/gnome/terminal/legacy" = {
            "default-show-menubar" = false;
        };

        "org/gnome/terminal/legacy/profiles:" = {
            default = profileCustom;
            list = [
                profileCustom
                profileDefault
            ];
        };

        "org/gnome/terminal/legacy/profiles:/:${profileCustom}" = {
            "visible-name" = "custom";
            "audible-bell" = false;
            "backspace-binding" = "ascii-delete";
            "cursor-blink-mode" = "system";
            "cursor-shape" = "ibeam";
            "default-size-columns" = 120;
            "delete-binding" = "delete-sequence";
            "font" = "JetBrainsMono Nerd Font Mono 15";
            "cell-width-scale" = 1.0;
            "cell-height-scale" = 1.10;
            "scroll-on-output" = true;
            "scrollback-lines" = 10000;
            "scrollbar-policy" = "always";
            "use-system-font" = false;
            "use-theme-colors" = true;
            "login-shell" = true;
            "use-custom-command" = true;
            "custom-command" = "zsh";
        };

        "org/gnome/terminal/legacy/profiles:/:${profileDefault}" = {
            "visible-name" = "default";
        };
    };
}
