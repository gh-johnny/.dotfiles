local fb_actions = require "telescope".extensions.file_browser.actions
require('telescope').setup {
    extensions = {
        file_browser = {
            theme = "ivy",
            hijack_netrw = false,
            path = vim.loop.cwd(),
            cwd = vim.loop.cwd(),
            cwd_to_path = false,
            grouped = false,
            files = true,
            add_dirs = true,
            depth = 1,
            auto_depth = false,
            select_buffer = false,
            hidden = { file_browser = false, folder_browser = false },
            respect_gitignore = vim.fn.executable "fd" == 1,
            no_ignore = false,
            follow_symlinks = true,
            browse_files = require("telescope._extensions.file_browser.finders").browse_files,
            browse_folders = require("telescope._extensions.file_browser.finders").browse_folders,
            hide_parent_dir = false,
            collapse_dirs = false,
            prompt_path = false,
            quiet = false,
            dir_icon = "",
            dir_icon_hl = "Default",
            display_stat = { date = true, size = true, mode = true },
            use_fd = true,
            git_status = true,
            mappings = {
                -- Default keybinds
                ["i"] = {
                    ["<A-c>"] = fb_actions.create,
                    ["<S-CR>"] = fb_actions.create_from_prompt,
                    ["<A-r>"] = fb_actions.rename,
                    ["<A-m>"] = fb_actions.move,
                    ["<A-y>"] = fb_actions.copy,
                    ["<A-d>"] = fb_actions.remove,
                    ["<C-o>"] = fb_actions.open,
                    ["<C-g>"] = fb_actions.goto_parent_dir,
                    ["<C-e>"] = fb_actions.goto_home_dir,
                    ["<C-w>"] = fb_actions.goto_cwd,
                    ["<C-t>"] = fb_actions.change_cwd,
                    ["<C-f>"] = fb_actions.toggle_browser,
                    ["<C-h>"] = fb_actions.toggle_hidden,
                    ["<C-s>"] = fb_actions.toggle_all,
                    ["<bs>"] = fb_actions.backspace,
                },
                -- Default + custom keybinds
                ["n"] = {
                    ["c"] = fb_actions.create,          -- Create file/folder at current path (trailing path separator creates folder)
                    ["r"] = fb_actions.rename,          -- Rename multi-selected files/folders
                    ["y"] = fb_actions.copy,            -- Copy (multi-)selected files/folders to current path
                    ["m"] = fb_actions.move,            -- Move multi-selected files/folders to current path
                    ["<S-d>"] = fb_actions.remove,      -- Delete (multi-)selected files/folders
                    ["-"] = fb_actions.goto_parent_dir, -- Go to parent directory
                    ["<S-b>"] = fb_actions.goto_cwd,    -- Go to current working directory (cwd)
                    ["h"] = fb_actions.toggle_hidden,   -- Toggle hidden files/folders
                },
            },
        },
    },
}
require('telescope').load_extension "file_browser"

vim.api.nvim_set_keymap('n', '<leader>fr', '<Cmd>Telescope file_browser<CR><Esc>',
    { noremap = true })
vim.api.nvim_set_keymap('n', '<leader>fb', '<Cmd>Telescope file_browser path=%:p:h select_buffer=true<CR><Esc>',
    { noremap = true })

-- vim.cmd("normal qqq")
