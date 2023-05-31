require("catppuccin").setup({
    flavour = "macchiato", -- latte, frappe, macchiato, mocha
    background = { -- :h background
        light = "latte",
        dark = "macchiato",
    },
    transparent_background = false,
    show_end_of_buffer = false, -- show the '~' characters after the end of buffers
    term_colors = false,
    dim_inactive = {
        enabled = true,
        shade = "dark",
        percentage = 0.15,
    },
    no_italic = false, -- Force no italic
    no_bold = false, -- Force no bold
    no_underline = false, -- Force no underline
    styles = {
        comments = { "italic" },
        conditionals = {},
        loops = {},
        functions = {},
        keywords = {},
        strings = {},
        variables = { "bold" },
        numbers = {},
        booleans = {},
        properties = {},
        types = {},
        operators = {},
    },
    color_overrides = {},
    custom_highlights = {},
    integrations = {
        cmp = true,
        gitsigns = true,
        nvimtree = true,
        telescope = true,
        notify = false,
        mini = false,
        -- For more plugins integrations please scroll down (https://github.com/catppuccin/nvim#integrations)
    },
})

-- setup must be called before loading
vim.cmd.colorscheme "catppuccin"  

-- Will returns a table where the key is the name of the color and the value is its hex value corresponding to each flavour.

-- local latte = require("catppuccin.palettes").get_palette "latte"
-- local frappe = require("catppuccin.palettes").get_palette "frappe"
-- local macchiato = require("catppuccin.palettes").get_palette "macchiato"
-- local mocha = require("catppuccin.palettes").get_palette "mocha"
-- 
-- Overwriting colors
-- Goto -> https://github.com/catppuccin/nvim#overwriting-colors
--
--require("catppuccin").setup {
    -- color_overrides = {
      --  all = {
        --    text = "#ffffff",
--        },
        -- latte = {
         --   base = "#ff0000",
        --    mantle = "#242424",
       --     crust = "#474747",
      --  },
     --   frappe = {},
    --    macchiato = {},
   --     mocha = {},
  --  }
-- }
