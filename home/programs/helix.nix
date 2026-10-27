{
    config,
    lib,
    pkgs,
    ...
}:
let
    editor = config.dotfiles.editor;
in
{
    config = lib.mkIf config.programs.helix.enable {
        programs.helix = {
            defaultEditor = editor.terminal == "helix";

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

                    cursor-shape = {
                        insert = "bar";
                    };

                    auto-save = {
                        focus-lost = true;
                        after-delay.enable = true;
                    };

                    indent-guides.render = true;
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
