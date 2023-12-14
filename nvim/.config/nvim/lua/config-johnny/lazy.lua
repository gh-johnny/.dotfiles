local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", -- latest stable release
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

local plugins = {

    -- Color scheme
    { "catppuccin/nvim",           name = "catppuccin" },

    -- Transparency
    { "xiyaowong/transparent.nvim" },

    -- Treesiter
    {
        'nvim-treesitter/nvim-treesitter',
        build = ":TSUpdate"
    },

    -- Telescope
    {
        'nvim-telescope/telescope.nvim',
        tag = '0.1.4',
        -- or                              , branch = '0.1.x',
        dependencies = { 'nvim-lua/plenary.nvim' }
    },
    -- Harpoon
    "ThePrimeagen/harpoon",

    -- Undotree
    "mbbill/undotree",

    -- LSP
    {
        'VonHeikemen/lsp-zero.nvim',
        branch = 'v2.x',
        dependencies = {
            -- LSP Support
            { 'neovim/nvim-lspconfig' }, -- Required
            {                            -- Optional
                'williamboman/mason.nvim',
                build = function()
                    pcall(vim.cmd, 'MasonUpdate')
                end,
            },
            { 'williamboman/mason-lspconfig.nvim' }, -- Optional

            -- Autocompletion
            { 'hrsh7th/nvim-cmp' },     -- Required
            { 'hrsh7th/cmp-nvim-lsp' }, -- Required
        }
    },

    -- Status bar
    {
        'nvim-lualine/lualine.nvim',
        requires = { 'nvim-tree/nvim-web-devicons', opt = true }
    },

    -- Comments
    'terrortylor/nvim-comment',

    -- Lua snip
    {
        'L3MON4D3/LuaSnip',
        -- follow latest release.
        version = "2.0.0", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
        -- install jsregexp (optional!).
        build = "make install_jsregexp"
    }, -- Required

    -- Vim fugitive
    'tpope/vim-fugitive',

    -- Git signs
    'lewis6991/gitsigns.nvim',

    -- Import cost
    {
        'barrett-ruth/import-cost.nvim',
        build = 'sh install.sh yarn',
        -- if on windows
        -- build = 'pwsh install.ps1 yarn',
        config = true
    },
}



local opts = {}

require("lazy").setup(plugins, opts)
