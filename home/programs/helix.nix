{
    config,
    lib,
    pkgs,
    crane,
    ...
}:
let
    editor = config.dotfiles.editor;
    colors = config.lib.stylix.colors;

    # "#rrggbb": `percent` of `over` mixed into `base` (both hex without the "#").
    mix =
        over: base: percent:
        let
            ch = hex: i: lib.fromHexString (builtins.substring i 2 hex);
            one =
                i:
                let
                    v = (ch over i * percent + ch base i * (100 - percent)) / 100;
                in
                (if v < 16 then "0" else "") + lib.toHexString v;
        in
        "#${one 0}${one 2}${one 4}";
in
{
    config = lib.mkIf config.programs.helix.enable {
        programs.helix = {
            defaultEditor = editor.terminal == "helix";

            # The stylix theme with a lighter, faded cursor line (the text color over
            # the background) instead of its dark one.
            settings.theme = lib.mkForce "stylix-tuned";
            themes.stylix-tuned = {
                inherits = "stylix";
                "ui.cursorline.primary".bg = mix colors.base05 colors.base00 14;
                "ui.cursorline.secondary".bg = mix colors.base05 colors.base00 14;
                # The line number on the cursor line shares that background.
                "ui.linenr.selected".bg = mix colors.base05 colors.base00 14;
                "ui.gutter.selected".bg = mix colors.base05 colors.base00 14;
            };

            # Opt-in: our fork with the shared picker (see home/helix/FORK.md).
            package = lib.mkIf editor.helixFork (pkgs.callPackage ../helix-fork.nix { craneLib = crane.mkLib pkgs; });

            extraPackages = with pkgs; [
                nil
                lua-language-server
                bash-language-server
                marksman
                vscode-langservers-extracted
                yaml-language-server
                docker-language-server
                neocmakelsp
                taplo
                typescript-language-server
                gopls
                rust-analyzer
                ruff
                zls
            ];

            settings = {
                editor = {
                    scroll-lines = editor.scroll_lines;
                    line-number = editor.line_number;
                    cursorline = true;
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

                    # Dock panels exist only in our fork; stock helix rejects the key.
                    leader = lib.mkIf editor.helixFork editor.leader;

                    docks = lib.mkIf editor.helixFork {
                        inherit (editor.docks) left right bottom;
                    };

                    cursor-shape = {
                        insert = "bar";
                    };

                    auto-save = {
                        focus-lost = true;
                        after-delay.enable = true;
                    };

                    indent-guides.render = true;

                    # Room for line numbers up to 999 without the text shifting.
                    gutters.line-numbers.min-width = 3;
                };

                keys = {
                    normal = {
                        "C-j" = "page_cursor_half_down";
                        "C-k" = "page_cursor_half_up";
                        "C-h" = "move_prev_word_start";
                        "C-l" = "move_next_word_start";
                        "C-up" = lib.replicate 10 "move_visual_line_up";
                        "C-down" = lib.replicate 10 "move_visual_line_down";
                        "C-left" = "move_prev_word_end";
                        "C-right" = "move_next_word_end";
                        "C-S-up" = lib.replicate 10 "extend_visual_line_up";
                        "C-S-down" = lib.replicate 10 "extend_visual_line_down";
                        "C-S-left" = "extend_prev_word_end";
                        "C-S-right" = "extend_next_word_end";
                        "home" = "goto_first_nonwhitespace";
                        "end" = "goto_line_end";
                        # move line (clobbers the default register)
                        "A-up" = [
                            "extend_to_line_bounds"
                            "delete_selection"
                            "move_line_up"
                            "paste_before"
                        ];
                        "A-down" = [
                            "extend_to_line_bounds"
                            "delete_selection"
                            "paste_after"
                        ];
                        # add next match of the selected word as another selection
                        "C-d" = [
                            "search_selection_detect_word_boundaries"
                            "extend_search_next"
                        ];
                    };
                    select = {
                        "C-up" = lib.replicate 10 "extend_visual_line_up";
                        "C-down" = lib.replicate 10 "extend_visual_line_down";
                        "C-left" = "extend_prev_word_end";
                        "C-right" = "extend_next_word_end";
                        "home" = "extend_to_first_nonwhitespace";
                        "end" = "extend_to_line_end";
                    };
                    insert = {
                        "C-backspace" = "delete_word_backward";
                        "C-del" = "delete_word_forward";
                        "home" = "goto_first_nonwhitespace";
                        "end" = "goto_line_end_newline";
                    };
                };
            };
        };
    };
}
