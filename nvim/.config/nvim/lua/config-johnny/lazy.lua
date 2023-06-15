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
    { "catppuccin/nvim", name = "catppuccin" },

    -- Treesiter
    {
        'nvim-treesitter/nvim-treesitter',
        build = ":TSUpdate"
    },

    -- Telescope
    {
        'nvim-telescope/telescope.nvim', tag = '0.1.1',
        -- or                              , branch = '0.1.1',
        dependencies = { 'nvim-lua/plenary.nvim' }
    },

    -- Harpoon
    "ThePrimeagen/harpoon",

    -- Vim practice
    "ThePrimeagen/vim-be-good",

    -- Undotree
    "mbbill/undotree",

    -- LSP 
    {
        'VonHeikemen/lsp-zero.nvim',
        branch = 'v2.x',
        dependencies = {
            -- LSP Support
            {'neovim/nvim-lspconfig'},             -- Required
            {                                      -- Optional
            'williamboman/mason.nvim',
            build = function()
                pcall(vim.cmd, 'MasonUpdate')
            end,
        },
        {'williamboman/mason-lspconfig.nvim'}, -- Optional

        -- Autocompletion
        {'hrsh7th/nvim-cmp'},     -- Required
        {'hrsh7th/cmp-nvim-lsp'}, -- Required
        {'L3MON4D3/LuaSnip'},     -- Required
        }
    },

    -- Status bar 
    -- 'feline-nvim/feline.nvim',

    {
        "arsham/arshamiser.nvim",
        dependencies = {
            "arsham/arshlib.nvim",
            "famiu/feline.nvim",
            "rebelot/heirline.nvim",
            "kyazdani42/nvim-web-devicons",
        },
        config = function()
            -- ignore any parts you don't want to use
            vim.cmd.colorscheme("arshamiser_light")
            require("arshamiser.feliniser")
            -- or:
             require("arshamiser.heirliniser")

            _G.custom_foldtext = require("arshamiser.folding").foldtext
            vim.opt.foldtext = "v:lua.custom_foldtext()"
            -- if you want to draw a tabline:
             vim.api.nvim_set_option("tabline", [[%{%v:lua.require("arshamiser.tabline").draw()%}]])
        end,
   },

   -- Multi cursor
   'mg979/vim-visual-multi',

   -- Comments
   'terrortylor/nvim-comment'

}



local opts = {}

require("lazy").setup(plugins, opts)
