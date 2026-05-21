local M = {}

local defaults = {
  state_file = function()
    return vim.fn.stdpath("state") .. "/vscode-productivity/usage.json"
  end,
}

local config = defaults
local loaded = false
local dirty = false
local save_pending = false
local registry = {}
local state = {
  version = 1,
  actions = {},
}

local function state_file()
  return type(config.state_file) == "function" and config.state_file() or config.state_file
end

local function ensure_parent_dir(path)
  local dir = vim.fn.fnamemodify(path, ":h")
  if dir and dir ~= "" then
    vim.fn.mkdir(dir, "p")
  end
end

local function load_state()
  if loaded then
    return
  end

  loaded = true
  local path = state_file()
  if vim.fn.filereadable(path) ~= 1 then
    return
  end

  local lines = vim.fn.readfile(path)
  if not lines or #lines == 0 then
    return
  end

  local ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if ok and type(decoded) == "table" then
    state.version = decoded.version or state.version
    state.actions = type(decoded.actions) == "table" and decoded.actions or state.actions
  end
end

local function save_state()
  local path = state_file()
  ensure_parent_dir(path)
  local ok, encoded = pcall(vim.json.encode, state)
  if ok and encoded then
    vim.fn.writefile({ encoded }, path)
    dirty = false
  end
end

local function schedule_save()
  if save_pending then
    return
  end

  save_pending = true
  vim.defer_fn(function()
    save_pending = false
    if dirty then
      save_state()
    end
  end, 800)
end

local function get_entry(id)
  load_state()
  state.actions[id] = state.actions[id] or {
    count = 0,
    last_used = 0,
  }
  return state.actions[id]
end

local function item_text(item)
  local shortcuts = #item.shortcuts > 0 and table.concat(item.shortcuts, ", ") or "-"
  local command = item.command and (":" .. item.command) or "-"
  local last_used = item.last_used > 0 and os.date("%Y-%m-%d %H:%M", item.last_used) or "never"
  return string.format("[%d] %s | %s | %s | %s", item.count, item.label, shortcuts, command, last_used)
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  load_state()

  local group = vim.api.nvim_create_augroup("vscode_productivity_usage", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      if dirty then
        save_state()
      end
    end,
  })
end

function M.register_actions(actions)
  load_state()
  for id, spec in pairs(actions) do
    registry[id] = {
      id = id,
      label = spec.label or id,
      shortcuts = spec.shortcuts or {},
      command = spec.command,
      run = spec.run,
    }
    get_entry(id)
  end
  dirty = true
  schedule_save()
end

function M.record(id)
  local entry = get_entry(id)
  entry.count = (entry.count or 0) + 1
  entry.last_used = os.time()
  dirty = true
  schedule_save()
end

function M.items()
  load_state()
  local items = {}
  for id, meta in pairs(registry) do
    local entry = get_entry(id)
    items[#items + 1] = {
      id = id,
      label = meta.label,
      shortcuts = meta.shortcuts or {},
      command = meta.command,
      count = entry.count or 0,
      last_used = entry.last_used or 0,
      run = meta.run,
    }
  end

  table.sort(items, function(a, b)
    if a.count ~= b.count then
      return a.count > b.count
    end
    if a.last_used ~= b.last_used then
      return a.last_used > b.last_used
    end
    return a.label < b.label
  end)

  return items
end

function M.open_picker()
  local items = M.items()
  if #items == 0 then
    vim.notify("No tracked productivity actions yet", vim.log.levels.INFO, { title = "vscode-productivity.nvim" })
    return
  end

  if pcall(require, "snacks") and require("snacks").picker then
    return require("snacks").picker.select(items, {
      prompt = "Most Used Productivity Actions",
      format_item = function(item)
        return item_text(item)
      end,
    }, function(item)
      if item and item.run then
        item.run()
      end
    end)
  end

  vim.ui.select(items, {
    prompt = "Most Used Productivity Actions",
    format_item = item_text,
  }, function(item)
    if item and item.run then
      item.run()
    end
  end)
end

return M
