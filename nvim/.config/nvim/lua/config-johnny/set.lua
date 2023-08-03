
-- Cursor (fat)
vim.opt.guicursor = ""

-- Line nums
vim.opt.nu = true
vim.opt.relativenumber = true

-- Indent formatting
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true

-- Backups
vim.opt.backup = false
vim.opt.swapfile = false

-- Undotree has access to long ago changes
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

-- Search highlight 
vim.opt.hlsearch = false
vim.opt.incsearch = true

-- Good colors
vim.opt.termguicolors = true

-- Line wrap 
vim.opt.wrap = false

-- Lines after scroll
vim.opt.scrolloff = 8

-- Updatetime
vim.opt.updatetime = 50


