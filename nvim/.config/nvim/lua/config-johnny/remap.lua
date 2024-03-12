-- Leader
vim.g.mapleader = " "

-- Exit file (default netrw)
vim.keymap.set("n", "<leader>q", vim.cmd.Ex)

-- Save
vim.keymap.set("n", "<leader>w", function()
    vim.cmd('wa')
end)

-- Format
vim.keymap.set("n", "<leader>fo", function()
    vim.lsp.buf.format()
end)

-- Center screen y position
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "G", "Gzz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- Center horizontally
vim.keymap.set("n", "zs", "zs50zh")

-- Drag line(s)
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- Clipboard
vim.keymap.set("v", "y", '"+y')
vim.keymap.set("v", "Y", '"+Y')
vim.keymap.set("n", "y", '"+y')
vim.keymap.set("n", "Y", '"+Y')

-- Control + c is the same as Esc
vim.keymap.set("n", "<C-c>", '<Esc>')
vim.keymap.set("i", "<C-c>", '<Esc>')
vim.keymap.set("x", "<C-c>", '<Esc>')

-- Insert line and goes back to normal mode
vim.keymap.set("n", "<A-o>", 'o<Esc>')
vim.keymap.set("n", "<A-O>", 'O<Esc>')

-- Cutting won't overwrite current paste register
vim.keymap.set("x", "p", "\"_dP")

-- Replaces the current registry in all file
vim.keymap.set("n", "<leader>r", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

-- Searches for the current word and activates cgn so that we can replace the next occurences
vim.keymap.set('n', 'cgn', '*#cgn')

-- Incremental search trough quickfix list
vim.keymap.set('n', '<C-n>', '<Cmd>cnext<CR>')
vim.keymap.set('n', '<C-N>', '<Cmd>cprevious<CR>')

-- Save all when nvim is suspended
vim.keymap.set("n", "<Control>z", "<Cmd>wa<CR><Control>z")
vim.keymap.set("v", "<Control>z", "<Cmd>wa<CR><Control>z")

--  To reload current file
vim.keymap.set("n", "<leader><leader>s", function()
    vim.cmd("so")
end)
