require('nvim-treesitter').setup({
    ensure_installed = {
        'bash',
        'dart',
        'tsx',
        'javascript',
        'typescript',
        'regex',
        'c',
        'vim',
        'vimdoc',
        'lua',
        'luadoc',
        'luap',
    },
})

-- Enable treesitter highlighting for all filetypes
vim.api.nvim_create_autocmd('FileType', {
    callback = function()
        pcall(vim.treesitter.start)
    end
})
