local lsp = require("lsp-zero")

lsp.preset("recommended")

lsp.ensure_installed({
    'lua_ls',
    'csharp_ls',
})

local cmp = require("cmp")
local cmp_select = { behavior = cmp.SelectBehavior.Select }

cmp.setup.filetype({ "sql" }, {
    sources = {
        { name = 'vim-dadbod-completion' },
        { name = 'buffer' },
    }
})

local cmp_mappings = lsp.defaults.cmp_mappings({
    ['<C-p>'] = cmp.mapping.select_prev_item(cmp_select),
    ['<C-n>'] = cmp.mapping.select_next_item(cmp_select),
    -- ['<C-y>'] = cmp.mapping.confirm({ select = true }),
    ['<Tab>'] = cmp.mapping.confirm({ select = true }),
    ['<C-Space>'] = cmp.mapping.complete(),
})

lsp.setup_nvim_cmp({
    mapping = cmp_mappings
})

lsp.setup()
