local builtin = require('telescope.builtin')

function live_grep_git_dir()
    local git_dir = vim.fn.system(string.format("git -C %s rev-parse --show-toplevel", vim.fn.expand("%:p:h")))
    git_dir = string.gsub(git_dir, "\n", "") -- remove newline character from git_dir
    local opts = {
        cwd = git_dir,
    }
    builtin.live_grep(opts)
end

vim.keymap.set('n', '<leader>fg', '<Cmd>lua live_grep_git_dir()<CR>')
vim.keymap.set('n', '<leader>pf', builtin.find_files, {})
-- vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<C-p>', builtin.git_files, {})

vim.keymap.set('n', "<leader>ps", function()
    builtin.grep_string({ search = vim.fn.input("Grep > ") });
end)
