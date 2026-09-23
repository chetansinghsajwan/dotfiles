{
  config,
  lib,
  pkgs,
  localLib,
  helix-wrapped,
  ...
}:
let
  editor = config.dotfiles.editor;
in
{
  home.packages = [
    (helix-wrapped.lib.mkHelix {
      inherit pkgs lib;
      inherit (localLib.wrapped.base16) substituteTemplate;

      # Was stylix.targets.helix.transparent in modules/stylix.nix - moved
      # here now that theming no longer flows through programs.helix.
      transparent = true;
      colors = config.lib.stylix.colors.withHashtag;

      extraPackages = with pkgs; [
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
          scroll-lines = editor.scroll_lines;
          line-number = editor.line_number;
          cursorline = true;
          cursorcolumn = true;
          continue-comments = true;
          true-color = true;
          inherit (editor) rulers;
          bufferline = "multiple";
          text-width = editor.text_width;
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
            normal = navigation;
            select = navigation;
          };
      };
    })
  ];

  # Was programs.helix.defaultEditor = true.
  home.sessionVariables = {
    EDITOR = "hx";
    VISUAL = "hx";
  };
}
