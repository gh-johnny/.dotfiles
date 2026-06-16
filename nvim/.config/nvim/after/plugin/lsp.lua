-- Pass nvim-cmp capabilities to all LSP servers
vim.lsp.config('*', {
    capabilities = require('cmp_nvim_lsp').default_capabilities(),
})

-- Per-server customization (merges with lspconfig's built-in server configs)
vim.lsp.config('lua_ls', {
    settings = {
        Lua = {
            diagnostics = {
                globals = { 'vim' }
            }
        }
    }
})

vim.lsp.config('eslint', {
    settings = {
        packageManager = 'pnpm'
    },
})

-- omnisharp-mono (manual install, not through mason)
vim.lsp.config('omnisharp', {
    cmd = { "omnisharp-mono", "--languageserver", "--hostPID", tostring(vim.fn.getpid()) },
    filetypes = { "cs", "vb" },
    root_markers = { ".git", "*.sln" },
})
vim.lsp.enable('omnisharp')

-- LSP on-attach: keybindings + eslint fix on save
vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        local opts = { buffer = ev.buf }

        vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
        vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
        vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
        vim.keymap.set('n', 'go', vim.lsp.buf.type_definition, opts)
        vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
        vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
        vim.keymap.set('n', '<F2>', vim.lsp.buf.rename, opts)
        vim.keymap.set('n', '<F3>', function() vim.lsp.buf.format({ async = true }) end, opts)
        vim.keymap.set('x', '<F3>', function() vim.lsp.buf.format({ async = true }) end, opts)
        vim.keymap.set('n', '<F4>', vim.lsp.buf.code_action, opts)

        if client and client.name == 'eslint' then
            vim.api.nvim_create_autocmd('BufWritePre', {
                buffer = ev.buf,
                command = 'EslintFixAll',
            })
        end
    end
})

-- Mason: install servers (automatic_enable = true by default → calls vim.lsp.enable per server)
require('mason').setup()
require('mason-lspconfig').setup({
    ensure_installed = { 'lua_ls' },
})

-- nvim-cmp completion
local cmp = require('cmp')
local cmp_select = { behavior = cmp.SelectBehavior.Select }

cmp.setup({
    sources = {
        { name = 'nvim_lsp' },
        { name = 'luasnip' },
    },
    mapping = cmp.mapping.preset.insert({
        ['<C-p>'] = cmp.mapping.select_prev_item(cmp_select),
        ['<C-n>'] = cmp.mapping.select_next_item(cmp_select),
        ['<Tab>'] = cmp.mapping.confirm({ select = true }),
        ['<C-Space>'] = cmp.mapping.complete(),
    }),
    snippet = {
        expand = function(args)
            require('luasnip').lsp_expand(args.body)
        end,
    },
})

cmp.setup.filetype({ 'sql' }, {
    sources = {
        { name = 'vim-dadbod-completion' },
        { name = 'buffer' },
    }
})
