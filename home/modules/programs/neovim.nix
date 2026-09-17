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
            vim.keymap.set("n", "<leader>fh", require("fzf-lua").help_tags, {})
          '';
        }
        {
          plugin = nvim-lspconfig;
          type = "lua";
          config = ''
            vim.lsp.enable({ "nil_ls", "lua_ls", "bashls" })
          '';
        }
        nvim-web-devicons
        {
          plugin = nvim-tree-lua;
          type = "lua";
          config = ''
            vim.g.loaded_netrw = 1
            vim.g.loaded_netrwPlugin = 1

            require("nvim-tree").setup({
              renderer = {
                root_folder_label = false,
              },
              view = {
                width = 30,
                float = {
                  enable = true,
                  open_win_config = function()
                    local height = vim.o.lines - vim.o.cmdheight - 2
                    return {
                      relative = "editor",
                      border = "rounded",
                      width = 30,
                      height = height,
                      row = 0,
                      col = 0,
                    }
                  end,
                },
              },
            })
            vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file explorer" })

            vim.api.nvim_create_autocmd("BufWinEnter", {
              callback = function()
                if vim.bo.filetype == "NvimTree" then
                  vim.opt_local.fillchars:append({ eob = " " })
                end
              end,
            })
          '';
        }
        {
          plugin = bufferline-nvim;
          type = "lua";
          config = ''
            require("bufferline").setup({})
            vim.keymap.set("n", "<Tab>", "<cmd>BufferLineCycleNext<CR>", { desc = "Next buffer" })
            vim.keymap.set("n", "<S-Tab>", "<cmd>BufferLineCyclePrev<CR>", { desc = "Prev buffer" })
            vim.keymap.set("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete buffer" })
          '';
        }
        {
          plugin = lualine-nvim;
          type = "lua";
          config = ''
            require("lualine").setup({
              options = {
                theme = "auto",
                globalstatus = true,
              },
              sections = {
                lualine_a = { "mode" },
                lualine_b = { "branch", "diff", "diagnostics" },
                lualine_c = { "filename" },
                lualine_x = { "filetype" },
                lualine_y = { "progress" },
                lualine_z = { "location" },
              },
            })
          '';
        }
      ];

      initLua = ''
        vim.g.mapleader = " "
        vim.g.maplocalleader = " "

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

        vim.keymap.set({ "n", "v" }, "J", "10jzz", { desc = "10 lines down" })
        vim.keymap.set({ "n", "v" }, "K", "10kzz", { desc = "10 lines up" })
        vim.keymap.set({ "n", "v" }, "<C-j>", "<C-f>zz", { desc = "Full page down" })
        vim.keymap.set({ "n", "v" }, "<C-k>", "<C-b>zz", { desc = "Full page up" })
      '';
    };

    home.shellAliases.nv = "nvim";
  };
}
