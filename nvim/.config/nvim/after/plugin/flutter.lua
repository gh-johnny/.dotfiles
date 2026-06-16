local ok, flutter = pcall(require, 'flutter-tools')
if not ok then return end

flutter.setup({
    ui = {
        border = 'rounded',
        notification_style = 'native',
    },
    decorations = {
        statusline = {
            app_version = true,
            device = true,
        },
    },
    debugger = {
        enabled = true,
        run_via_dap = true,
        register_configurations = function(_)
            require('dap').configurations.dart = {}
        end,
    },
    flutter_path = nil, -- auto-detected from PATH
    flutter_lookup_cmd = nil,
    fvm = false,
    widget_guides = { enabled = true },
    closing_tags = {
        highlight = 'ErrorMsg',
        prefix = '// ',
        priority = 10,
        enabled = true,
    },
    dev_log = {
        enabled = true,
        filter = nil,
        notify_errors = true,
        open_cmd = 'tabedit',
    },
    dev_tools = {
        autostart = false,
        auto_open_browser = false,
    },
    outline = {
        open_cmd = '30vnew',
        auto_open = false,
    },
    lsp = {
        color = {
            enabled = true,
            background = false,
            background_color = nil,
            foreground = false,
            virtual_text = true,
            virtual_text_str = '■',
        },
        settings = {
            showTodos = true,
            completeFunctionCalls = true,
            renameFilesWithClasses = 'prompt',
            enableSnippets = true,
            updateImportsOnRename = true,
        },
    },
})

-- keymaps
vim.keymap.set('n', '<leader>fr', ':FlutterRun<CR>', { noremap = true, desc = 'Flutter Run' })
vim.keymap.set('n', '<leader>fq', ':FlutterQuit<CR>', { noremap = true, desc = 'Flutter Quit' })
vim.keymap.set('n', '<leader>fR', ':FlutterRestart<CR>', { noremap = true, desc = 'Flutter Restart' })
vim.keymap.set('n', '<leader>fh', ':FlutterReload<CR>', { noremap = true, desc = 'Flutter Hot Reload' })
vim.keymap.set('n', '<leader>fd', ':FlutterDevices<CR>', { noremap = true, desc = 'Flutter Devices' })
vim.keymap.set('n', '<leader>fe', ':FlutterEmulators<CR>', { noremap = true, desc = 'Flutter Emulators' })
vim.keymap.set('n', '<leader>fo', ':FlutterOutlineToggle<CR>', { noremap = true, desc = 'Flutter Outline' })
vim.keymap.set('n', '<leader>fl', ':FlutterLogToggle<CR>', { noremap = true, desc = 'Flutter Log' })
vim.keymap.set('n', '<leader>fD', ':FlutterVisualDebug<CR>', { noremap = true, desc = 'Flutter Visual Debug' })
