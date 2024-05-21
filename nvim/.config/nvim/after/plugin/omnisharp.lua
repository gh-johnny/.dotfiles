local nvim_lsp = require('lspconfig')

nvim_lsp.omnisharp.setup {
    cmd = { "omnisharp-mono", "--languageserver", "--hostPID", tostring(vim.fn.getpid()) };
    filetypes = { "cs", "vb" };
    root_dir = nvim_lsp.util.root_pattern(".git", "*.sln");
}
