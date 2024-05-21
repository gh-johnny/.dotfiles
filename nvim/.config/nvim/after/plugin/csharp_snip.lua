local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
-- local f = ls.function_node

-- Console.WriteLine() snippet
ls.add_snippets("cs", {
  s("cw", {
    t("Console.WriteLine("), i(1), t(");")
  })
})

-- Curly braces go down
ls.add_snippets("cs", {
    s("{", {
        t({
            "",
            "{",
            "    "
        }),
        i(1),
        t({
            "",
            "}"
        })
    }),
})
