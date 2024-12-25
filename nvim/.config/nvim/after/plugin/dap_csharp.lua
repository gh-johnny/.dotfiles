local dap = require("dap")

dap.adapters.coreclr = {
    type = 'executable',
    command = '/home/johnny/.local/share/nvim/mason/packages/netcoredbg/netcoredbg',
    args = { '--interpreter=vscode' }
}

-- dap.configurations.cs = {
--     {
--         type = "coreclr",
--         name = "launch - netcoredbg",
--         request = "launch",
--         aprogram = function()
--             return vim.fn.input('Path to dll', vim.fn.getcwd() .. '/bin/Debug/', 'file')
--         end,
--     },
-- }

dap.configurations.cs = {
  {
    type = "coreclr",
    name = "launch - netcoredbg",
    request = "launch",
    program = function()
      local cwd = vim.fn.getcwd()
      local dll = cwd .. "/bin/Debug/net8.0/" .. vim.fn.fnamemodify(cwd, ":t") .. ".dll"
      return dll
    end,
    cwd = "${workspaceFolder}",
    env = {
      ASPNETCORE_ENVIRONMENT = "Development",
    },
  },
}

