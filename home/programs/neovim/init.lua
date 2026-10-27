vim.g.mapleader = " "

-- multi-cursor: <C-d> adds the next occurrence of the word under cursor (vim-visual-multi)
vim.g.VM_maps = { ["Find Under"] = "<C-d>", ["Find Subword Under"] = "<C-d>" }

local o = vim.o
o.number = true
o.relativenumber = vim.g.dotfiles.relativenumber
o.cursorline = true
o.termguicolors = true
o.scrolloff = vim.g.dotfiles.scroll_lines
o.colorcolumn = table.concat(vim.g.dotfiles.rulers, ",")
o.textwidth = vim.g.dotfiles.text_width
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4
o.signcolumn = "yes"
o.mouse = "a"
o.clipboard = "unnamedplus"
o.ignorecase = true
o.smartcase = true
o.undofile = true
o.splitright = true
o.splitbelow = true
o.autowriteall = true
o.fixendofline = true
o.list = true
o.listchars = "tab:» ,trail:·"

-- auto-save like helix's focus-lost / after-delay
vim.api.nvim_create_autocmd({ "FocusLost", "BufLeave", "CursorHold" }, {
    callback = function(ev)
        if vim.bo[ev.buf].modifiable and vim.bo[ev.buf].buftype == "" and vim.api.nvim_buf_get_name(ev.buf) ~= "" then
            vim.cmd("silent! update")
        end
    end,
})

-- trim trailing whitespace and final newlines on save
vim.api.nvim_create_autocmd("BufWritePre", {
    callback = function()
        local view = vim.fn.winsaveview()
        vim.cmd([[silent! keeppatterns %s/\s\+$//e]])
        vim.cmd([[silent! keeppatterns %s/\n\+\%$//e]])
        vim.fn.winrestview(view)
    end,
})

local map = vim.keymap.set

-- helix-style motions carried over from helix.nix
map("n", "<C-j>", "<C-d>zz", { desc = "Half page down" })
map("n", "<C-k>", "<C-u>zz", { desc = "Half page up" })
map("n", "<C-h>", "b", { desc = "Prev word" })
map("n", "<C-l>", "w", { desc = "Next word" })
map({ "n", "v" }, "<C-Up>", "10k", { desc = "10 lines up" })
map({ "n", "v" }, "<C-Down>", "10j", { desc = "10 lines down" })
map({ "n", "v" }, "<C-Left>", "ge", { desc = "Prev word end" })
map({ "n", "v" }, "<C-Right>", "e", { desc = "Next word end" })
map("i", "<C-Up>", "<C-o>10k", { desc = "10 lines up" })
map("i", "<C-Down>", "<C-o>10j", { desc = "10 lines down" })
map("i", "<C-Left>", "<C-o>ge", { desc = "Prev word end" })
map("i", "<C-Right>", "<C-o>e<Right>", { desc = "Next word end" })

-- shift extends the selection (starts visual mode from normal/insert)
map("n", "<C-S-Up>", "v10k", { desc = "Select 10 lines up" })
map("n", "<C-S-Down>", "v10j", { desc = "Select 10 lines down" })
map("n", "<C-S-Left>", "vge", { desc = "Select to prev word end" })
map("n", "<C-S-Right>", "ve", { desc = "Select to next word end" })
map("i", "<C-S-Up>", "<Esc>v10k", { desc = "Select 10 lines up" })
map("i", "<C-S-Down>", "<Esc>v10j", { desc = "Select 10 lines down" })
map("i", "<C-S-Left>", "<Esc>vge", { desc = "Select to prev word end" })
map("i", "<C-S-Right>", "<Esc>ve", { desc = "Select to next word end" })
map("v", "<C-S-Up>", "10k", { desc = "Select 10 lines up" })
map("v", "<C-S-Down>", "10j", { desc = "Select 10 lines down" })
map("v", "<C-S-Left>", "ge", { desc = "Select to prev word end" })
map("v", "<C-S-Right>", "e", { desc = "Select to next word end" })

-- home/end
map({ "n", "v" }, "<Home>", "^", { desc = "First non-blank" })
map({ "n", "v" }, "<End>", "$", { desc = "Line end" })
map("i", "<Home>", "<C-o>^", { desc = "First non-blank" })

-- move lines
map("n", "<A-Up>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
map("n", "<A-Down>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
map("i", "<A-Up>", "<Esc><cmd>m .-2<cr>==gi", { desc = "Move line up" })
map("i", "<A-Down>", "<Esc><cmd>m .+1<cr>==gi", { desc = "Move line down" })
map("v", "<A-Up>", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })
map("v", "<A-Down>", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })

map("i", "<C-BS>", "<C-w>", { desc = "Delete word backward" })
map("i", "<C-Del>", "<C-o>dw", { desc = "Delete word forward" })

-- tab bar
require("bufferline").setup({
    options = {
        diagnostics = "nvim_lsp",
        always_show_bufferline = false,
        offsets = {
            { filetype = "neo-tree", text = "Explorer", highlight = "Directory", separator = true },
        },
    },
})
map("n", "<S-h>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Prev buffer" })
map("n", "<S-l>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Close buffer" })
map("n", "<leader>bp", "<cmd>BufferLineTogglePin<cr>", { desc = "Pin buffer" })

-- file explorer
require("neo-tree").setup({
    close_if_last_window = true,
    filesystem = {
        follow_current_file = { enabled = true },
        filtered_items = { hide_dotfiles = false, hide_gitignored = false },
    },
})
map("n", "<leader>e", "<cmd>Neotree toggle<cr>", { desc = "Explorer" })
map("n", "<leader>E", "<cmd>Neotree reveal<cr>", { desc = "Explorer (reveal file)" })

-- fuzzy finder
local telescope = require("telescope")
telescope.setup({})
telescope.load_extension("fzf")
local tb = require("telescope.builtin")
map("n", "<leader>f", tb.find_files, { desc = "Find files" })
map("n", "<leader>/", tb.live_grep, { desc = "Grep" })
map("n", "<leader>b", tb.buffers, { desc = "Buffers" })
map("n", "<leader>s", tb.lsp_document_symbols, { desc = "Symbols" })
map("n", "<leader>S", tb.lsp_dynamic_workspace_symbols, { desc = "Workspace symbols" })
map("n", "<leader>d", tb.diagnostics, { desc = "Diagnostics" })
map("n", "<leader>?", tb.help_tags, { desc = "Help" })

-- treesitter (grammars are provided by nix)
vim.api.nvim_create_autocmd("FileType", {
    callback = function(ev)
        pcall(vim.treesitter.start, ev.buf)
    end,
})

-- lsp
vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })
vim.lsp.enable({
    "nil_ls",
    "lua_ls",
    "bashls",
    "marksman",
    "jsonls",
    "html",
    "cssls",
    "yamlls",
    "docker_language_server",
    "neocmake",
    "taplo",
    "ts_ls",
    "gopls",
    "rust_analyzer",
    "ruff",
    "zls",
})
vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(ev)
        local function bmap(lhs, rhs, desc)
            map("n", lhs, rhs, { buffer = ev.buf, desc = desc })
        end
        bmap("gd", vim.lsp.buf.definition, "Definition")
        bmap("gr", tb.lsp_references, "References")
        bmap("gi", vim.lsp.buf.implementation, "Implementation")
        bmap("K", vim.lsp.buf.hover, "Hover")
        bmap("<leader>r", vim.lsp.buf.rename, "Rename")
        bmap("<leader>a", vim.lsp.buf.code_action, "Code action")
        bmap("]d", function() vim.diagnostic.jump({ count = 1 }) end, "Next diagnostic")
        bmap("[d", function() vim.diagnostic.jump({ count = -1 }) end, "Prev diagnostic")
    end,
})
vim.diagnostic.config({ virtual_text = true, severity_sort = true })

-- completion
require("blink.cmp").setup({
    keymap = { preset = "default" },
    completion = { documentation = { auto_show = true } },
})

-- formatting
require("conform").setup({
    formatters_by_ft = {
        nix = { "nixfmt" },
        lua = { "stylua" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        python = { "ruff_format" },
    },
    format_on_save = { timeout_ms = 2000, lsp_format = "fallback" },
})
map({ "n", "v" }, "<leader>=", function()
    require("conform").format({ lsp_format = "fallback" })
end, { desc = "Format" })

-- git
require("gitsigns").setup({ current_line_blame = false })
map("n", "]g", "<cmd>Gitsigns next_hunk<cr>", { desc = "Next hunk" })
map("n", "[g", "<cmd>Gitsigns prev_hunk<cr>", { desc = "Prev hunk" })
map("n", "<leader>gp", "<cmd>Gitsigns preview_hunk<cr>", { desc = "Preview hunk" })
map("n", "<leader>gb", "<cmd>Gitsigns toggle_current_line_blame<cr>", { desc = "Toggle blame" })

-- ui
require("lualine").setup({ options = { globalstatus = true } })
require("which-key").setup({})

-- editing
require("mini.pairs").setup()
require("mini.comment").setup()

-- minimap
local minimap = require("mini.map")
minimap.setup({
    integrations = {
        minimap.gen_integration.builtin_search(),
        minimap.gen_integration.gitsigns(),
        minimap.gen_integration.diagnostic(),
    },
    symbols = { encode = minimap.gen_encode_symbols.dot("4x2") },
    window = { show_integration_count = false },
})
map("n", "<leader>m", minimap.toggle, { desc = "Minimap" })
vim.api.nvim_create_autocmd("VimEnter", { callback = minimap.open })

-- keep plugin windows transparent too (stylix only clears the main buffer)
vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
        for _, group in ipairs({
            "NormalFloat",
            "NeoTreeNormal",
            "NeoTreeNormalNC",
            "NeoTreeEndOfBuffer",
            "StatusLine",
            "StatusLineNC",
            "TabLineFill",
        }) do
            vim.api.nvim_set_hl(0, group, { bg = "NONE" })
        end
    end,
})
