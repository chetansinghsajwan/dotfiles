{
    config,
    lib,
    pkgs,
    ...
}:
let
    editor = config.dotfiles.editor;
    vp = pkgs.vimPlugins;

    # `relative` is spelled "reative" in the option enum; match on it as declared.
    relativeNumber = editor.line_number == "reative";
in
{
    config = lib.mkIf config.programs.neovim.enable {
        home.shellAliases.nv = "nvim";

        programs.neovim = {
            defaultEditor = editor.terminal == "neovim";
            viAlias = true;
            vimAlias = true;
            withPython3 = false;
            withRuby = false;

            extraPackages = with pkgs; [
                # language servers
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

                # formatters
                nixfmt
                stylua
                shfmt

                # telescope
                ripgrep
                fd
            ];

            plugins = [
                vp.nvim-web-devicons
                vp.plenary-nvim
                vp.nui-nvim

                vp.bufferline-nvim
                vp.neo-tree-nvim
                vp.telescope-nvim
                vp.telescope-fzf-native-nvim
                vp.nvim-treesitter.withAllGrammars
                vp.nvim-lspconfig
                vp.blink-cmp
                vp.gitsigns-nvim
                vp.lualine-nvim
                vp.which-key-nvim
                vp.conform-nvim
                vp.mini-pairs
                vp.mini-comment
                vp.mini-map
                vp.vim-visual-multi
            ];

            initLua = ''
                vim.g.dotfiles = ${
                    lib.generators.toLua { } {
                        relativenumber = relativeNumber;
                        scroll_lines = editor.scroll_lines;
                        text_width = editor.text_width;
                        inherit (editor) rulers;
                    }
                }
                ${builtins.readFile ./neovim/init.lua}
            '';
        };
    };
}
