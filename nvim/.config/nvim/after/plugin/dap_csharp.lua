local dap = require("dap")

dap.adapters.coreclr = {
    type = 'executable',
    command = '/home/johnny/.local/share/nvim/mason/packages/netcoredbg/netcoredbg',
    args = { '--interpreter=vscode' }
}

dap.configurations.cs = {
    {
        type = "coreclr",
        name = "launch - netcoredbg",
        request = "launch",
        aprogram = function()
            return vim.fn.input('Path to dll', vim.fn.getcwd() .. '/bin/Debug/', 'file')
        end,
    },
}
