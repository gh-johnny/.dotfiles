local colors = {
    blue   = '#8aadf4',
    green  = '#a6da95',
    black  = '#1e2030',
    white  = '#cad3f5',
    red    = '#ed8796',
    violet = '#b788f2',
    orange = '#f5a97f',
}

local bubbles_theme = {
    normal = {
        a = { fg = colors.red, bg = colors.black },
        b = { fg = colors.white, bg = colors.black },
        c = { fg = colors.red, bg = colors.black },
    },

    insert = {
        a = { fg = colors.green, bg = colors.black },
        b = { fg = colors.white, bg = colors.black },
        c = { fg = colors.green, bg = colors.black },
    },
    visual = {
        a = { fg = colors.violet, bg = colors.black },
        b = { fg = colors.white, bg = colors.black },
        c = { fg = colors.violet, bg = colors.black },
    },
    replace = {
        a = { fg = colors.blue, bg = colors.black },
        b = { fg = colors.white, bg = colors.black },
        c = { fg = colors.blue, bg = colors.black },
    },

    inactive = {
        a = { fg = colors.white, bg = colors.black },
        b = { fg = colors.white, bg = colors.black },
        c = { fg = colors.black, bg = colors.black },
    },
}

local function endColumns()
    return '▊'
end

require('lualine').setup {
    options = {
        theme = bubbles_theme,
        component_separators = { left = '', right = '|' },
        section_separators = { left = '', right = '' },
        { fmt = string.lower },
    },
    sections = {
        lualine_a = {
            { endColumns },
            { 'mode',    separator = { left = nil, right = nil }, fmt = function(str) return str.lower(str) .. '  |' end }
        },
        lualine_b = {
            {
                'branch',
            },
            {
                'filename',
                symbols = {
                    modified = '',
                    readonly = '[R]',
                }
            },
        },
        lualine_c = {
            'fileformat',
        },
        lualine_x = {},
        lualine_y = { 'filetype', 'progress' },
        lualine_z = {
            { 'location', separator = { right = ' ' } },
            { endColumns },
        },
    },
    inactive_sections = {
        lualine_a = { 'filename' },
        lualine_b = {},
        lualine_c = {},
        lualine_x = {},
        lualine_y = {},
        lualine_z = { 'location' },
    },
    tabline = {},
    extensions = {},
}
