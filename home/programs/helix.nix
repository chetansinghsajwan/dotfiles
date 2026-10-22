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
            defaultEditor = true;

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
                    };
                };
            };
        };
    };
}
