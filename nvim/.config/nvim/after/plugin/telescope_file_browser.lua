local fb_actions = require "telescope".extensions.file_browser.actions
local fb_utils = require "telescope._extensions.file_browser.utils"
local Path = require "plenary.path"
local os_sep = Path.path.sep
local action_state = require "telescope.actions.state"
local async = require "plenary.async"

local get_target_dir = function(finder)
  local entry_path
  if finder.files == false then
    local entry = action_state.get_selected_entry()
    entry_path = entry and entry.value -- absolute path
  end
  return finder.files and finder.path or entry_path
end

local function get_input(opts, callback)
  local fb_config = require "telescope._extensions.file_browser.config"
  if fb_config.values.use_ui_input then
    vim.ui.input(opts, callback)
  else
    async.run(function()
      return vim.fn.input(opts)
    end, callback)
  end
end

local get_file_name = function (path)
    local separator = "/"
    local parts = {}
    for part in string.gmatch(path, "[^"..separator.."]+") do
        table.insert(parts, part)
    end
    return (parts[#parts]:gsub("%..+$", ""):gsub("[%-_](%w)", function(c)
        return c:upper()
    end):gsub("^%l", string.upper))
end

local check_file_extension = function (filename)
    local dotIndex = filename:find("%.[^%.]*$")
    if dotIndex then
        local extension = filename:sub(dotIndex + 1, -1)
        return extension
    end
end

local create = function(file, finder)
  if not file then
    return
  end
  if
    file == ""
    or (finder.files and file == finder.path .. os_sep)
    or (not finder.files and file == finder.cwd .. os_sep)
  then
    fb_utils.notify(
      "actions.create",
      { msg = "Please enter a valid file or folder name!", level = "WARN", quiet = finder.quiet }
    )
    return
  end
  file = Path:new(file)
  if file:exists() then
    fb_utils.notify("actions.create", { msg = "Selection already exists!", level = "WARN", quiet = finder.quiet })
    return
  end
  if not fb_utils.is_dir(file.filename) then
    file:touch { parents = true }
    if file then
        if check_file_extension(file.filename) == 'tsx' then
            local declaration = "export default function " .. get_file_name(file.filename) .. "(){\n"
            local return_html = "\t return (\n\t\t<>\n\t\t\t<h1>Hello " .. get_file_name(file.filename) .. "</h1>\n\t\t</>\n\t)\n}"
            local textToAppend = declaration .. return_html
            file:write(textToAppend, "a")
            file:close()
        end
    else
        fb_utils.notify("actions.create", { msg = "Could not append text!", level = "WARN", quiet = finder.quiet })
    end
  else
    Path:new(file.filename:sub(1, -2)):mkdir { parents = true, mode = 493 } -- 493 => decimal for mode 0755
  end
  return file
end

local function newly_created_root(path, cwd)
  local idx
  local parents = path:parents()
  cwd = fb_utils.sanitize_path_str(cwd)
  for i, p in ipairs(parents) do
    if p == cwd then
      idx = i
      break
    end
  end

  if idx == nil then
    return nil
  end
  return idx == 1 and path:absolute() or parents[idx - 1]
end

require('telescope').setup {
    extensions = {
        file_browser = {
            theme = "ivy",
            hijack_netrw = false,
            path = vim.loop.cwd(),
            cwd = vim.loop.cwd(),
            cwd_to_path = false,
            grouped = false,
            files = true,
            add_dirs = true,
            depth = 1,
            auto_depth = false,
            select_buffer = false,
            hidden = { file_browser = false, folder_browser = false },
            respect_gitignore = vim.fn.executable "fd" == 1,
            no_ignore = false,
            follow_symlinks = true,
            browse_files = require("telescope._extensions.file_browser.finders").browse_files,
            browse_folders = require("telescope._extensions.file_browser.finders").browse_folders,
            hide_parent_dir = false,
            collapse_dirs = false,
            prompt_path = false,
            quiet = false,
            dir_icon = "",
            dir_icon_hl = "Default",
            display_stat = { date = true, size = true, mode = true },
            use_fd = true,
            git_status = true,
            mappings = {
                -- Default keybinds
                ["i"] = {
                    -- ["<A-c>"] = fb_actions.create,
                    ["<A-c>"] = fb_actions.create,
                    ["<S-CR>"] = fb_actions.create_from_prompt,
                    ["<A-r>"] = fb_actions.rename,
                    ["<A-m>"] = fb_actions.move,
                    ["<A-y>"] = fb_actions.copy,
                    ["<A-d>"] = fb_actions.remove,
                    ["<C-o>"] = fb_actions.open,
                    ["<C-g>"] = fb_actions.goto_parent_dir,
                    ["<C-e>"] = fb_actions.goto_home_dir,
                    ["<C-w>"] = fb_actions.goto_cwd,
                    ["<C-t>"] = fb_actions.change_cwd,
                    ["<C-f>"] = fb_actions.toggle_browser,
                    ["<C-h>"] = fb_actions.toggle_hidden,
                    ["<C-s>"] = fb_actions.toggle_all,
                    ["<bs>"] = fb_actions.backspace,
                },
                -- Default + custom keybinds
                ["n"] = {
                    ["c"] = function(prompt_bufnr)
                        local current_picker = action_state.get_current_picker(prompt_bufnr)
                        local finder = current_picker.finder

                        local base_dir = get_target_dir(finder) .. os_sep
                        get_input({ prompt = "Create: ", default = base_dir, completion = "file" }, function(input)
                          vim.cmd [[ redraw ]] -- redraw to clear out vim.ui.prompt to avoid hit-enter prompt
                          local file = create(input, finder)
                          if file then
                            local selection_path = newly_created_root(file, base_dir)
                            if selection_path then
                              fb_utils.selection_callback(current_picker, selection_path)
                            end
                            current_picker:refresh(finder, { reset_prompt = true, multi = current_picker._multi })
                          end
                        end)
                        end, -- Create file/folder at current path (trailing path separator creates folder)
                    ["r"] = fb_actions.rename,          -- Rename multi-selected files/folders
                    ["y"] = fb_actions.copy,            -- Copy (multi-)selected files/folders to current path
                    ["m"] = fb_actions.move,            -- Move multi-selected files/folders to current path
                    ["<S-d>"] = fb_actions.remove,      -- Delete (multi-)selected files/folders
                    ["-"] = fb_actions.goto_parent_dir, -- Go to parent directory
                    ["<S-b>"] = fb_actions.goto_cwd,    -- Go to current working directory (cwd)
                    ["h"] = fb_actions.toggle_hidden,   -- Toggle hidden files/folders
                },
            },
        },
    },
}
require('telescope').load_extension "file_browser"

vim.api.nvim_set_keymap('n', '<leader>fr', '<Cmd>Telescope file_browser<CR><Esc>',
    { noremap = true })
vim.api.nvim_set_keymap('n', '<leader>fb', '<Cmd>Telescope file_browser path=%:p:h select_buffer=true<CR><Esc>',
    { noremap = true })
