-- Leader
vim.g.mapleader = " "

vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

-- Center screen y position
vim.keymap.set("n", "<leader>f", function()
    vim.lsp.buf.format()
end)
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "j", "jzz")
vim.keymap.set("n", "k", "kzz")
vim.keymap.set("n", "G", "Gzz")

-- Drag line(s)
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- Saving
vim.keymap.set("n", "<Esc>", "<Esc><Cmd>w<CR>")
vim.keymap.set("v", "<Esc>", "<Esc><Cmd>w<CR>")
vim.keymap.set("i", "<Esc>", "<Esc><Cmd>w<CR>")
vim.keymap.set("n", "<Control>z", "<Cmd>w<CR><Control>z")
vim.keymap.set("v", "<Control>z", "<Cmd>w<CR><Control>z")
