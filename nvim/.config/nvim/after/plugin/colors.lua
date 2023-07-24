-- Global function to call the colors, easier to change some specs 
function ColorMyPencils(color)
    color = color or "catppuccin"
    vim.cmd.colorscheme(color)

    vim.api.nvim_set_hl(1, "Normal", { bg = "none" })
    vim.api.nvim_set_hl(1, "NormalFloat", { bg = "none" })
end

ColorMyPencils()
