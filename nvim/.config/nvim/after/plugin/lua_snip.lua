local ls = require("luasnip")
-- local fmt = require("luasnip.extras.fmt").fmt
local s = ls.snippet
-- local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
-- local c = ls.choice_node
-- local d = ls.dynamic_node
-- local r = ls.restore_node
-- local l = require("luasnip.extras").lambda
-- local rep = require("luasnip.extras").rep
-- local p = require("luasnip.extras").partial
-- local m = require("luasnip.extras").match
-- local n = require("luasnip.extras").nonempty
-- local dl = require("luasnip.extras").dynamic_lambda
-- local fmt = require("luasnip.extras.fmt").fmt
-- local fmta = require("luasnip.extras.fmt").fmta
local types = require("luasnip.util.types")
-- local conds = require("luasnip.extras.conditions")
-- local conds_expand = require("luasnip.extras.conditions.expand")

vim.keymap.set({ "i" }, "<C-K>", function() ls.expand() end, { silent = true })
vim.keymap.set({ "i", "s" }, "<C-s>", function() ls.jump(1) end, { silent = true })
vim.keymap.set({ "i", "s" }, "<C-w>", function() ls.jump(-1) end, { silent = true })
vim.keymap.set('n', '<leader><leader>w',
    "<Cmd>source ~/.dotfiles/nvim/.config/nvim/after/plugin/lua_snip.lua<CR>")

vim.keymap.set({ "i", "s" }, "<C-i>", function()
    if ls.choice_active() then
        ls.change_choice(1)
    end
end, { silent = true })

ls.setup({
    keep_roots = true,
    link_roots = true,
    link_children = true,

    update_events = "TextChanged,TextChangedI",
    delete_check_events = "TextChanged",
    ext_opts = {
        [types.choiceNode] = {
            active = {
                virt_text = { { "choiceNode", "Comment" } },
            },
        },
    },
    ext_base_prio = 300,
    ext_prio_increase = 1,
    enable_autosnippets = true,
    store_selection_keys = "<C-i>",
    ft_func = function()
        return vim.split(vim.bo.filetype, ".", true)
    end,
})

ls.add_snippets('css', {
    s("{", {
        t({ "{", "    " }),
        i(1),
        t({ "", "}" })
    }),
}, {
    type = "autosnippets",
    key = "css-braces", -- unique id
})

ls.add_snippets("all", {
    s("{}", {
        t("{"),
        i(1),
        t("}"),
        i(2)
    }),
}, {
    type = "autosnippets",
})

ls.add_snippets("all", {
    s("[]", {
        t("["),
        i(1),
        t("]"),
        i(2)
    }),
}, {
    type = "autosnippets",
})

ls.add_snippets("all", {
    s("()", {
        t("("),
        i(1),
        t(")"),
        i(2)
    }),
}, {
    type = "autosnippets",
})

ls.add_snippets("all", {
    s("''", {
        t("'"),
        i(1),
        t("'"),
        i(2)
    }),
}, {
    type = "autosnippets",
})

ls.add_snippets("all", {
    s('""', {
        t('"'),
        i(1),
        t('"'),
        i(2)
    }),
}, {
    type = "autosnippets",
})

ls.add_snippets("all", {
    s('``', {
        t('`'),
        i(1),
        t('`'),
        i(2)
    }),
}, {
    type = "autosnippets",
})

function GetFileName()
    local fileName = vim.fn.substitute(vim.fn.expand('%:t'), '\\(.*\\)\\..*$', '\\1', '')
    vim.cmd('normal kj')
    return (fileName:gsub("[%-_](%w)", function(c)
        return c:upper()
    end):gsub("^%l", string.upper))
end

ls.add_snippets('typescriptreact', {
    s('rfun', {
        t("export default function "),
        f(GetFileName),
        t({ "() {", "    return (", "        <>", "" }),
        t("            <h1>Hello "),
        i(1),
        f(GetFileName),
        t("</h1>"),
        t({ "", "        </>", "    )", "}" })
    })
})


ls.add_snippets('typescriptreact', {
    s('af', {
        t("const "),
        i(1),
        t(" = () => {"),
        t({ "", "}" })
    })
})


ls.add_snippets('typescript', {
    s('c', {
        t('console.log('),
        i(1),
        t(')')
    })
})

ls.add_snippets('typescriptreact', {
    s('c', {
        t('console.log('),
        i(1),
        t(')')
    })
})

-- require("luasnip.loaders.from_vscode").load({ paths = { "./my-snippets" } }) -- Load snippets from my-snippets folder
--
-- require("luasnip.loaders.from_snipmate").load({ path = { "./my-snippets" } })
--
-- require("luasnip.loaders.from_snipmate").lazy_load() -- Lazy loading
