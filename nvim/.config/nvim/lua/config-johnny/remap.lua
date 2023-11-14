-- Leader
vim.g.mapleader = " "

vim.keymap.set("n", "<leader>q", vim.cmd.Ex)

-- Save and format
vim.keymap.set("n", "<leader>w", function()
    vim.lsp.buf.format()
    vim.cmd('w')
end)

-- vim.keymap.set("n", "<leader>f", function()
--     vim.lsp.buf.format()
-- end)

-- Center screen y position
vim.keymap.set("n", "<C-d>", "<C-d>zz4<C-e>")
vim.keymap.set("n", "<C-u>", "<C-u>zz4<C-e>")
vim.keymap.set("n", "G", "Gzz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")
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

-- Greatest remap ever
vim.keymap.set("x", "p", "\"_dP")
vim.keymap.set("n", "<leader>r", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

vim.keymap.set("n", "<Control>z", "<Cmd>w<CR><Control>z")
vim.keymap.set("v", "<Control>z", "<Cmd>w<CR><Control>z")

vim.keymap.set("n", "<leader><leader>s", function()
    vim.cmd("so")
end)
