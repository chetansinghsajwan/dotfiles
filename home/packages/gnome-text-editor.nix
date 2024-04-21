{ config, pkgs, ... }:
{
    home.packages = [
        pkgs.gnome-text-editor
        pkgs.cascadia-code
    ];

    dconf.settings."org/gnome/TextEditor" = {
        "auto-indent" = true;
        "use-system-font" = false;
        "custom-font" = "Cascadia Code PL 14";
        "highlight-current-line" = true;
        "highlight-matching-brackets" = true;
        "indent-style" = "space";
        "keybindings" = "default";
        "line-height" = 1.2;
        "restore-session" = false;
        "show-grid" = false;
        "show-line-numbers" = true;
        "show-map" = true;
        "show-right-margin" = true;
        "right-margin-position" = 80;
        "spellcheck" = true;
        "style-scheme" = "classic-dark";
        "style-variant" = "follow";
        "tab-width" = 4;
        "wrap-text" = true;
    };
}