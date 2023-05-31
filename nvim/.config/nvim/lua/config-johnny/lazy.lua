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
}



local opts = {}

require("lazy").setup(plugins, opts)
