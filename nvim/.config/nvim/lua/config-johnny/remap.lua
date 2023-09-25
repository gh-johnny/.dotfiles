-- Leader
vim.g.mapleader = " "

vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

-- Center screen y position
vim.keymap.set("n", "<leader>w", function()
    vim.lsp.buf.format()
    vim.cmd('w')
end)

vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "G", "Gzz")
-- vim.keymap.set("n", "j", "jzz")
-- vim.keymap.set("n", "k", "kzz")

-- Drag line(s)
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- Clipboard
vim.keymap.set("v", "<leader>y", '"+y')
vim.keymap.set("v", "<leader>Y", '"+Y')
vim.keymap.set("n", "<leader>y", '"+y')
vim.keymap.set("n", "<leader>Y", '"+Y')
-- vim.keymap.set("v", "<leader>pa", '"+p')
-- vim.keymap.set("v", "<leader>Pa", '"+P')
-- vim.keymap.set("n", "<leader>pa", '"+p')
-- vim.keymap.set("n", "<leader>Pa", '"+P')

-- Saving
-- vim.keymap.set("n", "<Esc>", "<Esc><Cmd>w<CR>")
-- vim.keymap.set("v", "<Esc>", "<Esc><Cmd>w<CR>")
-- vim.keymap.set("i", "<Esc>", "<Esc><Cmd>w<CR>")
vim.keymap.set("n", "<Control>z", "<Cmd>w<CR><Control>z")
vim.keymap.set("v", "<Control>z", "<Cmd>w<CR><Control>z")
