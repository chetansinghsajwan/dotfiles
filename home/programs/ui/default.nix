{ config, pkgs, ... }:
let
    ui = config.dotfiles.ui;
    c = config.lib.stylix.colors.withHashtag;
in
{
    # Shared TUI framework crate. Only the demo binary is installed for now;
    # tools (pv, pick, ...) will depend on the crate directly.
    home.packages = [ (pkgs.callPackage ../../crates { } "ui") ];

    # Single source of design tokens. Read at runtime by the `ui` crate
    # (home/crates/ui), so editing a value needs no rebuild of any tool.
    xdg.configFile."ui/theme.json".text = builtins.toJSON {
        colors = {
            bg = c.base00;
            fg = c.base05;
            muted = c.base03;
            accent = c.base0D;
            border = c.base03;
            border_focused = c.base0D;
            selection = c.base02;
            error = c.base08;
            warning = c.base0A;
            success = c.base0B;
            info = c.base0C;
            syntax = {
                comment = c.base03;
                keyword = c.base0E;
                function = c.base0D;
                string = c.base0B;
                number = c.base09;
                type_ = c.base0A;
                constant = c.base09;
                variable = c.base08;
                operator = c.base0C;
            };
            git = {
                added = c.base0B;
                modified = c.base0A;
                deleted = c.base08;
                untracked = c.base0C;
                conflict = c.base09;
                renamed = c.base0D;
            };
        };
        chrome = {
            inherit (ui.chrome) border titles transparent;
            editor_box = ui.chrome.editorBox;
        };
        layout = {
            inherit (ui.layout) gap;
            padding_x = ui.layout.paddingX;
            padding_y = ui.layout.paddingY;
            sidebar_width = ui.layout.sidebarWidth;
            preview_percent = ui.layout.previewPercent;
            popup_percent = ui.layout.popupPercent;
            bottom_height = ui.layout.bottomHeight;
        };
    };
}
