--- vscode-productivity.nvim - Panel state persistence
---
--- Saves which VS Code-style panels (explorer, problems, terminal, outline)
--- are open on exit and restores them on next start — just like VS Code
--- remembers your window layout between sessions.
---
--- Enabled by default. Disable or customize in setup():
--- ```lua
--- require("vscode_productivity").setup({
---   panel_persistence = {
---     enabled = false,              -- disable entirely
---     state_file = "custom/path",   -- custom state file path
---     panels = {                    -- add or override panel specs
---       my_panel = {
---         label = "My Panel",
---         filetypes = { "my-ft" },
---         check = function() ... end,
---         open = function() ... end,
---       },
---     },
---   },
--- })
--- ```

local M = {}

local defaults = {
  enabled = true,
  state_file = function()
    return vim.fn.stdpath("state") .. "/vscode-productivity/panels.json"
  end,
  panels = {},
}

--- Default panel specs. These detect common VS Code-style panels
--- by inspecting open windows and reopen them using the plugin's
--- own :VSCode* commands (backend-agnostic).
local default_panels = {
  explorer = {
    label = "Explorer",
    filetypes = { "neo-tree" },
    check = function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype == "neo-tree"
          and vim.b[buf].neo_tree_source == "filesystem" then
          return true
        end
      end
      return false
    end,
    open = function()
      pcall(vim.cmd, "VSCodeExplorer")
    end,
  },
  problems = {
    label = "Problems",
    filetypes = { "trouble" },
    check = function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype == "trouble" then
          return true
        end
      end
      return false
    end,
    open = function()
      pcall(vim.cmd, "VSCodeProblems")
    end,
  },
  terminal_right = {
    label = "Terminal (Right)",
    filetypes = { "toggleterm" },
    check = function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype == "toggleterm"
          and vim.b[buf].toggleterm_id == 2 then
          return true
        end
      end
      return false
    end,
    open = function()
      pcall(require("vscode_productivity").toggle_term_edge, 2, 80, "vertical")
    end,
  },
  terminal = {
    label = "Terminal",
    filetypes = { "toggleterm" },
    check = function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype == "toggleterm"
          and vim.b[buf].toggleterm_id == 1 then
          return true
        end
      end
      return false
    end,
    open = function()
      pcall(vim.cmd, "VSCodeTerminal")
    end,
  },
  outline = {
    label = "Outline",
    filetypes = { "aerial" },
    check = function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype == "aerial" then
          return true
        end
      end
      return false
    end,
    open = function()
      pcall(vim.cmd, "VSCodeOutline")
    end,
  },
}

local config = {}
local panels = {}

local function state_file()
  return type(config.state_file) == "function"
    and config.state_file()
    or config.state_file
end

local function save()
  local state = {}
  for name, spec in pairs(panels) do
    local visible = spec.check()
    state[name] = { visible = visible }
  end
  local path = state_file()
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  pcall(function()
    local f = io.open(path, "w")
    if f then
      f:write(vim.json.encode(state))
      f:close()
    end
  end)
end

local function restore()
  local path = state_file()
  local f = io.open(path, "r")
  if not f then return end
  local content = f:read("*a")
  f:close()
  if not content or content == "" then return end
  local ok, state = pcall(vim.json.decode, content)
  if not ok or not state then return end

  -- Double-schedule to run after session restore and UI setup
  vim.schedule(function()
    vim.schedule(function()
      local order = { "explorer", "problems", "terminal_right", "terminal", "outline" }
      for _, name in ipairs(order) do
        local entry = state[name]
        if entry and entry.visible then
          local spec = panels[name]
          if spec then spec.open() end
        end
      end
    end)
  end)
end

--- Register a custom panel spec.
---@param name string Panel identifier
---@param spec table { label, filetypes, check, open }
function M.register_panel(name, spec)
  panels[name] = spec
end

--- Setup panel persistence.
---@param opts table|nil Configuration
function M.setup(opts)
  config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})

  if config.enabled == false then
    return
  end

  -- Start with defaults, then merge user panels
  panels = vim.deepcopy(default_panels)
  for name, spec in pairs(config.panels) do
    panels[name] = spec
  end

  local group = vim.api.nvim_create_augroup("vscode_productivity_persistence", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    desc = "Save VS Code panel states",
    callback = save,
  })
  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    desc = "Restore VS Code panel states",
    once = true,
    callback = restore,
  })
end

return M
