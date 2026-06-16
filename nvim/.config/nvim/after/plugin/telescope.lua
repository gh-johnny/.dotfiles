local builtin = require('telescope.builtin')

require('telescope').setup({
    defaults = {
        preview = {
            treesitter = false,
        },
    },
})

function Live_grep_git_dir()
    local git_dir = vim.fn.system(string.format("git -C %s rev-parse --show-toplevel", vim.fn.expand("%:p:h")))
    git_dir = string.gsub(git_dir, "\n", "") -- remove newline character from git_dir
    local opts = {
        cwd = git_dir,
    }
    builtin.live_grep(opts)
end

vim.keymap.set('n', '<leader>fg', '<Cmd>lua Live_grep_git_dir()<CR>')
vim.keymap.set('n', '<leader>pf', builtin.find_files, {})
-- vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
function Find_files_fallback()
    local status_ok, _ = pcall(builtin.git_files)
    if not status_ok then
        builtin.find_files()
    end
end

vim.keymap.set('n', '<C-p>', Find_files_fallback, {})

vim.keymap.set('n', "<leader>ps", function()
    builtin.grep_string({ search = vim.fn.input("Grep > ") });
end)
