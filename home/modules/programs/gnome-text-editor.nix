{ config, pkgs, lib, ... }:
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
        "right-margin-position" = 100;
        "spellcheck" = false;
        "style-scheme" = "classic-dark";
        "style-variant" = "follow";
        "tab-width" = lib.hm.gvariant.mkUint32 4;
        "wrap-text" = false;
    };
}