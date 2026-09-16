{ config, lib, pkgs, ... }: {
  config = lib.mkIf config.programs.neovim.enable {
    programs.neovim = {
      withRuby = false;
      withPython3 = false;
      defaultEditor = true;

      extraPackages = with pkgs; [
        nil
        lua-language-server
        bash-language-server
      ];

      plugins = with pkgs.vimPlugins; [
        {
          plugin = nvim-treesitter.withPlugins (p: [
            p.nix
            p.lua
            p.bash
            p.vim
            p.vimdoc
            p.markdown
            p.markdown_inline
            p.json
            p.yaml
          ]);
          type = "lua";
          config = ''
            require("nvim-treesitter").setup({})
            vim.treesitter.language.register("bash", "sh")

            local ts_filetypes = {
              "nix", "lua", "bash", "sh", "vim", "vimdoc",
              "markdown", "markdown_inline", "json", "yaml",
            }
            vim.api.nvim_create_autocmd("FileType", {
              pattern = ts_filetypes,
              callback = function()
                vim.treesitter.start()
                vim.bo.indentexpr = "v:lua.require('nvim-treesitter').indentexpr()"
              end,
            })
          '';
        }
        {
          plugin = gitsigns-nvim;
          type = "lua";
          config = ''require("gitsigns").setup()'';
        }
        {
          plugin = comment-nvim;
          type = "lua";
          config = ''require("Comment").setup()'';
        }
        {
          plugin = fzf-lua;
          type = "lua";
          config = ''
            require("fzf-lua").setup({})
            vim.keymap.set("n", "<leader>ff", require("fzf-lua").files, {})
            vim.keymap.set("n", "<leader>fg", require("fzf-lua").live_grep, {})
            vim.keymap.set("n", "<leader>fb", require("fzf-lua").buffers, {})
          '';
        }
        {
          plugin = nvim-lspconfig;
          type = "lua";
          config = ''
            vim.lsp.enable({ "nil_ls", "lua_ls", "bashls" })
          '';
        }
      ];

      initLua = ''
        vim.o.termguicolors = true
        vim.o.tabstop = 4
        vim.o.expandtab = true
        vim.o.softtabstop = 4
        vim.o.shiftwidth = 4
        vim.o.number = true
        vim.o.ignorecase = true
        vim.o.smartcase = true
        vim.o.scrolloff = 8
        vim.o.clipboard = "unnamedplus"
        vim.o.splitright = true
        vim.o.splitbelow = true
      '';
    };

    home.shellAliases.nv = "nvim";
  };
}
