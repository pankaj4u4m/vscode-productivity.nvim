--- vscode-productivity.nvim - VS Code-style clickable statusline icons
---
--- Provides a Heirline/statusline `opts` override function that adds clickable
--- icon buttons to your statusline. Designed for AstroNvim but works with any
--- Heirline-based statusline.
---
--- Usage with lazy.nvim:
--- ```lua
--- {
---   "rebelot/heirline.nvim",
---   opts = require("vscode_productivity.statusline").overrides(),
--- }
--- ```
---
--- To customize icons, pass them to `overrides()`:
--- ```lua
--- require("vscode_productivity.statusline").overrides({
---   icons = {
---     explorer = "󰙅",
---     ...
---   },
--- })
--- ```

local M = {}

local defaults = {
  icons = {},
  ---@type table[]|nil Custom left entries (nil = use defaults)
  left_entries = nil,
  ---@type table[]|nil Custom right entries (nil = use defaults)
  right_entries = nil,
}

local function window_visible(filetype)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == filetype then
      return true
    end
  end
  return false
end

local function terminal_id_visible(id)
  local ok, terms = pcall(require, "toggleterm.terminal")
  if ok then
    local term = terms.get(id)
    return term and term:is_open() or false
  end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "toggleterm" then
      return true
    end
  end
  return false
end



--- Create a clickable statusline button component
local function vscode_button(config)
  return {
    provider = "  " .. config.icon .. "  ",
    hl = function()
      if config.is_active and config.is_active() then
        return { fg = "#61afef", bold = true }
      end
      return { fg = "#abb2bf" }
    end,
    on_click = {
      callback = config.callback,
      name = "vscode_" .. config.name,
    },
  }
end

--- Default left-side entries (appear at the start of the statusline)
---@param icons table Icon overrides
---@param actions table Action functions from vscode_productivity
local function default_left_entries(icons, actions)
  return {
    {
      name = "explorer",
      label = "Explorer",
      icon = icons.explorer or "󰙅",
      shortcuts = { "<C-b>", "<Leader>e" },
      command = "VSCodeExplorer",
      callback = actions.toggle_explorer,
      is_active = function()
        return window_visible "neo-tree"
      end,
    },
    {
      name = "quick_open",
      label = "Quick Open",
      icon = icons.quick_open or "󰈞",
      shortcuts = { "<C-p>", "<Leader>ff" },
      command = "VSCodeQuickOpen",
      callback = actions.quick_open,
    },
    {
      name = "recent_files",
      label = "Recent Files",
      icon = icons.recent_files or "󰑩",
      shortcuts = { "<Leader>fr" },
      command = "VSCodeRecent",
      callback = actions.recent_files,
    },
    {
      name = "search_project",
      label = "Search in Files",
      icon = icons.search_project or "",
      shortcuts = { "<Leader>/", "<Leader>sg" },
      command = "VSCodeSearch",
      callback = actions.search_project,
    },
    {
      name = "search_replace",
      label = "Search and Replace",
      icon = icons.search_replace or "󱎸",
      shortcuts = { "<Leader>sr" },
      command = "VSCodeSearchReplace",
      callback = actions.search_replace,
    },
    {
      name = "projects",
      label = "Projects",
      icon = icons.projects or "",
      shortcuts = { "<Leader>fp" },
      command = "VSCodeProjects",
      callback = actions.projects,
    },
    {
      name = "command_palette",
      label = "Command Palette",
      icon = icons.command_palette or "",
      shortcuts = { "<Leader>sp", "<Leader>a" },
      command = "VSCodeCommandPalette",
      callback = actions.command_palette,
    },
    {
      name = "git_panel",
      label = "Git Status",
      icon = icons.git_panel or "󰊢",
      shortcuts = { "<Leader>gt" },
      callback = function()
        require("snacks").picker.git_status()
      end,
    },
    {
      name = "git_file_history",
      label = "File History",
      icon = icons.git_file_history or "󰋘",
      shortcuts = { "<Leader>gf" },
      command = "VSCodeFileHistory",
      callback = actions.git_file_history,
    },
    {
      name = "problems",
      label = "Problems",
      icon = icons.problems or "󰅩",
      shortcuts = { "<Leader>xx" },
      command = "VSCodeProblems",
      callback = actions.toggle_problems,
      is_active = function()
        return window_visible "trouble"
      end,
    },
    {
      name = "terminal",
      label = "Terminal",
      icon = icons.terminal or "",
      shortcuts = { "<C-`>" },
      command = "VSCodeTerminal",
      callback = actions.toggle_terminal,
      is_active = function()
        return terminal_id_visible(1)
      end,
    },
  }
end

--- Default right-side entries (appear at the end of the statusline)
---@param icons table Icon overrides
---@param actions table Action functions from vscode_productivity
local function default_right_entries(icons, actions)
  local function open_right_terminal()
    require("vscode_productivity").toggle_term_edge(2, 80, "vertical")
  end

  return {
    {
      name = "dock_help",
      label = "Dock Help",
      icon = icons.dock_help or "",
      shortcuts = { "<Leader>si" },
      command = "VSCodeDockHelp",
      callback = actions.dock_help,
    },
    {
      name = "usage",
      label = "Most Used Actions",
      icon = icons.usage or "",
      shortcuts = { "<Leader>sA" },
      command = "VSCodeUsage",
      callback = actions.usage_picker,
    },
    {
      name = "notifications",
      label = "Notifications",
      icon = icons.notifications or "",
      shortcuts = { "<Leader>n" },
      command = "VSCodeNotifications",
      callback = actions.notifications,
    },
    {
      name = "tasks",
      label = "Tasks",
      icon = icons.tasks or "󱂬",
      shortcuts = { "<Leader>ot" },
      command = "VSCodeTasks",
      callback = actions.toggle_tasks,
      is_active = function()
        return window_visible "OverseerList"
      end,
    },
    {
      name = "run_task",
      label = "Run Task",
      icon = icons.run_task or "󱑽",
      shortcuts = { "<Leader>or" },
      command = "VSCodeRunTask",
      callback = actions.run_task,
    },
    {
      name = "terminal_right",
      label = "Terminal (Right)",
      icon = icons.terminal_right or "",
      command = "VSCodeTerminalRight",
      callback = open_right_terminal,
      is_active = function()
        return terminal_id_visible(2)
      end,
    },
    {
      name = "todo",
      label = "Todo List",
      icon = icons.todo or "",
      shortcuts = { "<Leader>st" },
      command = "VSCodeTodo",
      callback = actions.todo_list,
    },
    {
      name = "symbols",
      label = "Workspace Symbols",
      icon = icons.symbols or "󰒓",
      shortcuts = { "<Leader>sS" },
      callback = actions.workspace_symbols,
    },
    {
      name = "outline",
      label = "Outline",
      icon = icons.outline or "󰯘",
      shortcuts = { "<Leader>xo" },
      command = "VSCodeOutline",
      callback = actions.toggle_outline,
      is_active = function()
        return window_visible "aerial"
      end,
    },
    {
      name = "debug",
      label = "Debug",
      icon = icons.debug or "",
      shortcuts = { "<Leader>du" },
      callback = function()
        local ok, dapui = pcall(require, "dapui")
        if ok then
          dapui.toggle({})
        elseif pcall(require, "dap") then
          vim.notify("[Debug] nvim-dap-ui not installed. Use :Lazy install nvim-dap-ui", vim.log.levels.INFO)
        else
          vim.notify("[Debug] nvim-dap not installed. Use :Lazy install nvim-dap", vim.log.levels.INFO)
        end
      end,
      is_active = function()
        return window_visible "dapui"
      end,
    },
    {
      name = "edit_history",
      label = "Edit History",
      icon = icons.edit_history or "󱞁",
      shortcuts = { "<Leader>su" },
      command = "VSCodeEditHistory",
      callback = actions.edit_history,
    },
    {
      name = "jumps",
      label = "Jumps",
      icon = icons.jumps or "󰕍",
      shortcuts = { "<Leader>sj" },
      command = "VSCodeJumps",
      callback = actions.jumps,
    },
    {
      name = "quickfix",
      label = "Quickfix List",
      icon = icons.quickfix or "󱖫",
      shortcuts = { "<Leader>sq" },
      command = "VSCodeQuickfix",
      callback = actions.quickfix_list,
    },
    {
      name = "buffers",
      label = "Buffers",
      icon = icons.buffers or "󰈙",
      shortcuts = { "<Leader>fb" },
      command = "VSCodeBuffers",
      callback = actions.buffers,
    },
  }
end

--- Create a Heirline `opts` override that adds VS Code-style statusline buttons.
---
--- This function returns an `opts` callback suitable for use with lazy.nvim:
---
--- ```lua
--- {
---   "rebelot/heirline.nvim",
---   opts = require("vscode_productivity.statusline").overrides(),
--- }
--- ```
---
--- For AstroNvim, this integrates with their Heirline configuration.
--- For standalone Heirline, provide your own base statusline entries.
---
---@param user_config table|nil Configuration table with optional fields:
---   - icons: table of icon overrides (key = entry name, value = icon string)
---   - left_entries: table[] of custom left entries (nil = use defaults)
---   - right_entries: table[] of custom right entries (nil = use defaults)
---@return function The opts callback for Heirline
function M.overrides(user_config)
  user_config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), user_config or {})

  return function(_, opts)
    local actions = require("vscode_productivity").actions()

    local left_entries = user_config.left_entries
      or default_left_entries(user_config.icons, actions)
    local right_entries = user_config.right_entries
      or default_right_entries(user_config.icons, actions)

    -- Register dock entries for the dock_help action
    local dock_entries = {}
    for i, entry in ipairs(left_entries) do
      table.insert(dock_entries, {
        icon = entry.icon,
        label = entry.label,
        id = entry.name,
        side = "left",
        index = i,
        run = entry.callback,
        shortcuts = entry.shortcuts,
        command = entry.command,
      })
    end
    for i, entry in ipairs(right_entries) do
      table.insert(dock_entries, {
        icon = entry.icon,
        label = entry.label,
        id = entry.name,
        side = "right",
        index = i,
        run = entry.callback,
        shortcuts = entry.shortcuts,
        command = entry.command,
      })
    end
    pcall(require("vscode_productivity").register_dock_entries, dock_entries)

    -- Build left button components
    local left_buttons = { { provider = " " } } -- left edge padding
    for _, entry in ipairs(left_entries) do
      table.insert(left_buttons, vscode_button(entry))
    end

    -- Build right button components
    local right_buttons = {}
    for _, entry in ipairs(right_entries) do
      table.insert(right_buttons, vscode_button(entry))
    end
    table.insert(right_buttons, { provider = " " }) -- right edge padding

    -- Build new statusline: [left buttons] + [existing components] + [right buttons]
    local new_statusline = {}

    -- Preserve the top-level hl default from the original opts
    if opts.statusline and opts.statusline[1] and opts.statusline[1].hl then
      new_statusline[1] = opts.statusline[1]
    else
      new_statusline[1] = { hl = { fg = "fg", bg = "bg" } }
    end

    -- Insert left buttons after hl default
    for _, btn in ipairs(left_buttons) do
      table.insert(new_statusline, btn)
    end

    -- Copy existing statusline components (skip index 1 which was hl default)
    if opts.statusline then
      for i = 2, #opts.statusline do
        table.insert(new_statusline, opts.statusline[i])
      end
    end

    -- Append right buttons at the end
    for _, btn in ipairs(right_buttons) do
      table.insert(new_statusline, btn)
    end

    opts.statusline = new_statusline
    return opts
  end
end

return M
