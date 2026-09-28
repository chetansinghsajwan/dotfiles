# nix-wrapper-modules wrapper module: pulls in nix-wrapper-modules' own
# native helix module plus this repo's customization (settings, editor
# sizing, theme) on top - so this one file is the complete helix wrapper,
# and callers only ever need to reference it, not also list
# `wrappers.wrapperModules.helix` separately. Theming is this module's
# own responsibility end to end: `colors` defaults to this repo's own
# default base16 theme, so a standalone build is themed out of the box
# with no outer config needed at all. Whatever imports this (see
# flake.nix's `homeModules.default`) may still override `colors` with a
# live palette (e.g. Stylix's) when one is available.
{
  config,
  lib,
  pkgs,
  wlib,
  ...
}:
{
  imports = [
    wlib.wrapperModules.helix

    # Purely so `colors` below (and editor.{scroll-lines,line-number,
    # rulers,text-width} below) can default to config.dotfiles.* - the
    # same config/default.nix options this repo's home-manager hosts
    # already get, just merged into this wrapper module's own isolated
    # evalModules instead of home-manager's. pkgs/lib/config are already
    # shared module args, so this needs no separate evalModules call or
    # specialArgs threading.
    ../../../config

    # Sets config.settings.theme/config.themes.stylix from config.colors.
    ./theme.nix
  ];

  options.colors = lib.mkOption {
    type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
    default = config.dotfiles.theme.colors;
    defaultText = lib.literalExpression "config.dotfiles.theme.colors";
    description = ''
      base16 palette as { base00 = "#hex"; ...; base0F = "#hex"; }, e.g.
      `config.lib.stylix.colors.withHashtag`. Defaults to this repo's own
      config.dotfiles.theme.colors; set to null to leave helix unthemed
      (its own defaults) instead.
    '';
  };

  config = {
    runtimePkgs = with pkgs; [
      nil
      lua-language-server
      bash-language-server
      marksman
      vscode-langservers-extracted
      yaml-language-server
    ];

    settings = {
      editor = {
        mouse = true;
        middle-click-paste = false;
        cursorline = true;
        cursorcolumn = true;
        continue-comments = true;
        true-color = true;
        bufferline = "multiple";
        color-modes = true;
        default-line-ending = "lf";
        insert-final-newline = true;
        trim-final-newlines = true;
        trim-trailing-whitespace = true;
        popup-border = "all";

        cursor-shape = {
          normal = "block";
          insert = "bar";
          select = "underline";
        };

        auto-save = {
          focus-lost = true;
          after-delay.enable = true;
        };

        indent-guides.render = true;

        statusline = {
          left = [
            "mode"
            "spinner"
            "file-name"
          ];
          center = [ ];
          right = [
            "diagnostics"
            "selections"
            "position"
            "file-encoding"
          ];
        };

        scroll-lines = config.dotfiles.editor.scroll_lines;
        line-number = config.dotfiles.editor.line_number;
        inherit (config.dotfiles.editor) rulers;
        text-width = config.dotfiles.editor.text_width;
      };

      keys =
        let
          navigation = {
            "C-h" = "move_prev_word_start";
            "C-l" = "move_next_word_start";
            "C-j" = "page_cursor_half_down";
            "C-k" = "page_cursor_half_up";
            "C-A-h" = "goto_line_start";
            "C-A-l" = "goto_line_end";
            "C-A-j" = "goto_last_line";
            "C-A-k" = "goto_file_start";
            "A-j" = "goto_next_function";
            "A-k" = "goto_prev_function";
          };
        in
        {
          normal = navigation // {
            # Bare "q" is macro-record by default; quit lives under the
            # space leader instead so it stays a deliberate chord rather
            # than a stray keypress, and macro-record keeps working.
            space.q = ":quit";
            space.Q = ":quit!";
          };
          select = navigation;
        };
    };
  };
}
