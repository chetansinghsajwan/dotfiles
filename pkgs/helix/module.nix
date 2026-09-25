# This repo's own helix customization. The editor.{scroll-lines,line-number,
# rulers,text-width} settings (sourced from config.dotfiles.editor) and
# theming are set separately by whatever imports this (see flake.nix's
# `homeModules.default`), since it needs the outer home-manager config - a
# plain wrapper module like this one only ever sees its own submodule
# config, not the config around it.
{ pkgs, ... }:
{
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
