local ng = require("ng")
local opts = { noremap = true, silent = true }

vim.keymap.set("n", "<leader>gt", ng.goto_template_for_component, opts)
vim.keymap.set("n", "<leader>gc", ng.goto_component_with_template_file, opts)
vim.keymap.set("n", "<leader>gT", ng.get_template_tcb, opts)
