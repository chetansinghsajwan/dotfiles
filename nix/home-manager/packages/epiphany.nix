{ pkgs, ... }:
{
    home.packages = [
        pkgs.epiphany
    ];

    dconf.settings."org/gnome/epiphany" = {
        "default-search-engine" = "Google";
        "use-google-search-suggestions" = true;
        "homepage-url" = "about:newtab";
        "restore-session-policy" = "crashed";
        "web/default-zoom-level" = 1.2;
        "web/enable-mouse-gestures" = true;
        "web/remember-passwords" = false;
        "web/use-gnome-fonts" = true;
        "web/enable-webextensions" = true;
    };
}