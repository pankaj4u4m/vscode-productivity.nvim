local M = {}

local defaults = {
  enable_vscode_keymaps = true,
  usage = {},
  integrations = {
    explorer = nil,
    terminal = nil,
    problems = nil,
    outline = nil,
    tasks = nil,
    agent_terminal = nil,
  },
  --- Panel state persistence: remembers which panels are open across restarts.
  --- Set to false to disable, or a table with custom options.
  ---@type boolean|table
  panel_persistence = true,
}

local config = vim.deepcopy(defaults)
local dock_entries = {}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "vscode-productivity.nvim" })
end

local function has_module(name)
  local ok, _ = pcall(require, name)
  return ok
end

local function has_command(name)
  return vim.fn.exists(":" .. name) == 2
end

local function invoke(integration)
  if type(integration) == "function" then
    integration()
    return true
  end

  return false
end

local function feedkeys(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "n", false)
end

local function current_word()
  local word = vim.fn.expand("<cword>")
  if type(word) == "string" and word ~= "" then
    return word
  end
end

local function current_file()
  local path = vim.api.nvim_buf_get_name(0)
  if type(path) == "string" and path ~= "" then
    return vim.fs.normalize(path)
  end
end

local function git_root(path)
  if not path or path == "" then
    return nil
  end
  local dir = vim.fn.fnamemodify(path, ":p:h")
  local found = vim.fs.find(".git", { path = dir, upward = true })[1]
  return found and vim.fn.fnamemodify(found, ":h") or nil
end

local function git_has_history(path)
  local root = git_root(path)
  if not root then
    return false
  end

  local rel = path
  if vim.startswith(path, root .. "/") then
    rel = path:sub(#root + 2)
  end
  local result = vim.fn.systemlist({
    "git",
    "-C",
    root,
    "rev-list",
    "--max-count=1",
    "HEAD",
    "--",
    rel,
  })

  return vim.v.shell_error == 0 and type(result) == "table" and result[1] ~= nil and result[1] ~= ""
end

local function visual_selection()
  local mode = vim.fn.mode()
  if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
    return nil
  end

  local start_pos = vim.fn.getpos("v")
  local end_pos = vim.fn.getpos(".")
  local start_line = start_pos[2]
  local end_line = end_pos[2]
  local start_col = start_pos[3]
  local end_col = end_pos[3]

  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    start_line, end_line = end_line, start_line
    start_col, end_col = end_col, start_col
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  if #lines == 0 then
    return nil
  end

  lines[1] = string.sub(lines[1], start_col)
  lines[#lines] = string.sub(lines[#lines], 1, end_col)
  return table.concat(lines, "\n")
end

local function lsp_supports(method, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return #vim.lsp.get_clients({ bufnr = bufnr, method = method }) > 0
end

local function fallback_normal(keys)
  local before = vim.api.nvim_win_get_cursor(0)
  pcall(vim.cmd, "normal! " .. keys)
  local after = vim.api.nvim_win_get_cursor(0)
  return before[1] ~= after[1] or before[2] ~= after[2]
end

local function with_picker(snacks_fn, telescope_fn, fzf_fn)
  if has_module("snacks") then
    local snacks = require("snacks")
    if snacks.picker and snacks.picker[snacks_fn] then
      return function(opts)
        snacks.picker[snacks_fn](opts or {})
      end
    end
  end

  if has_module("telescope.builtin") then
    local telescope = require("telescope.builtin")
    if telescope[telescope_fn] then
      return function(opts)
        telescope[telescope_fn](opts or {})
      end
    end
  end

  if has_module("fzf-lua") then
    local fzf = require("fzf-lua")
    if fzf[fzf_fn] then
      return function(opts)
        fzf[fzf_fn](opts or {})
      end
    end
  end
end

local function quick_open()
  local open = with_picker("files", "find_files", "files")
  if open then
    return open()
  end

  notify("No file picker is available", vim.log.levels.WARN)
end

local function buffers()
  local open = with_picker("buffers", "buffers", "buffers")
  if open then
    return open()
  end

  notify("No buffer picker is available", vim.log.levels.WARN)
end

local function recent_files()
  local open = with_picker("recent", "oldfiles", "oldfiles")
  if open then
    return open()
  end

  notify("No recent-files picker is available", vim.log.levels.WARN)
end

local function projects()
  if has_module("snacks") then
    local snacks = require("snacks")
    if snacks.picker and snacks.picker.projects then
      return snacks.picker.projects()
    end
  end

  notify("No projects picker is available", vim.log.levels.WARN)
end

local function command_palette()
  local open = with_picker("commands", "commands", "commands")
  if open then
    return open()
  end

  notify("No command palette backend is available", vim.log.levels.WARN)
end

local function notifications()
  if has_module("snacks") then
    local snacks = require("snacks")
    if snacks.picker and snacks.picker.notifications then
      return snacks.picker.notifications()
    end
  end

  notify("No notifications picker is available", vim.log.levels.WARN)
end

local function jumps()
  if has_module("snacks") then
    local snacks = require("snacks")
    if snacks.picker and snacks.picker.jumps then
      return snacks.picker.jumps()
    end
  end

  notify("No jumps picker is available", vim.log.levels.WARN)
end

local function quickfix_list()
  if vim.fn.getqflist({ size = 0 }).size == 0 then
    notify("Quickfix list is empty", vim.log.levels.INFO)
    return
  end

  if has_module("snacks") then
    local snacks = require("snacks")
    if snacks.picker and snacks.picker.qflist then
      return snacks.picker.qflist()
    end
  end

  if has_command("Trouble") then
    return vim.cmd("Trouble qflist toggle")
  end

  vim.cmd("copen")
end

local function search_project()
  local open = with_picker("grep", "live_grep", "live_grep")
  if open then
    return open()
  end

  notify("No project-search backend is available", vim.log.levels.WARN)
end

local function search_word()
  local selection = visual_selection()

  if selection and has_module("snacks") then
    local snacks = require("snacks")
    if snacks.picker and snacks.picker.grep then
      return snacks.picker.grep({ search = selection })
    end
  end

  local open = with_picker("grep_word", "grep_string", "grep_cword")
  if open then
    if selection then
      return open({ search = selection })
    end
    return open()
  end

  local word = current_word()
  if not word then
    notify("No word under cursor to search", vim.log.levels.WARN)
    return
  end

  vim.fn.setqflist({}, "r", {
    lines = vim.fn.systemlist("rg --vimgrep " .. vim.fn.shellescape(word)),
    efm = "%f:%l:%c:%m",
    title = "Search: " .. word,
  })
  vim.cmd("copen")
end

local function search_replace()
  if has_module("grug-far") then
    local grug = require("grug-far")
    local search = visual_selection() or current_word()
    return grug.open({
      transient = true,
      prefills = {
        search = search,
      },
    })
  end

  notify("grug-far.nvim is not available", vim.log.levels.WARN)
end

local function todo_list()
  if has_module("snacks") then
    local snacks = require("snacks")
    if snacks.picker and snacks.picker.todo_comments then
      return snacks.picker.todo_comments()
    end
  end

  if has_command("TodoQuickFix") then
    vim.cmd("silent TodoQuickFix")
    if vim.fn.getqflist({ size = 0 }).size > 0 then
      return quickfix_list()
    end
    notify("No TODO comments found", vim.log.levels.INFO)
    return
  end

  if has_command("TodoTrouble") then
    return vim.cmd("TodoTrouble")
  end

  notify("No todo picker is available", vim.log.levels.WARN)
end

local function edit_history()
  if has_module("snacks") then
    local snacks = require("snacks")
    if snacks.picker and snacks.picker.undo then
      return snacks.picker.undo()
    end
  end

  notify("No undo-history picker is available", vim.log.levels.WARN)
end

local function git_file_history()
  local path = current_file()
  if not path then
    notify("Current buffer has no file path yet", vim.log.levels.INFO)
    return
  end

  if not git_root(path) then
    notify("Current file is not inside a Git repository", vim.log.levels.INFO)
    return
  end

  if not git_has_history(path) then
    notify("No Git history for this file yet; showing edit history instead", vim.log.levels.INFO)
    return edit_history()
  end

  if has_module("snacks") then
    local snacks = require("snacks")
    if snacks.picker and snacks.picker.git_log_file then
      local ok, err = pcall(snacks.picker.git_log_file)
      if ok then
        return
      end
      notify("File history backend failed; trying fallback", vim.log.levels.WARN)
      vim.schedule(function()
        notify(err, vim.log.levels.DEBUG)
      end)
    end
  end

  if has_module("snacks") then
    local snacks = require("snacks")
    if snacks.lazygit and snacks.lazygit.log_file then
      return snacks.lazygit.log_file()
    end
  end

  notify("No file-history backend is available", vim.log.levels.WARN)
end

local function toggle_explorer()
  if invoke(config.integrations.explorer) then
    return
  end

  if has_module("neo-tree.command") then
    return require("neo-tree.command").execute({ toggle = true, source = "filesystem", position = "left" })
  end

  if has_module("snacks") then
    local snacks = require("snacks")
    if snacks.explorer then
      return snacks.explorer()
    end
  end

  notify("No explorer backend is available", vim.log.levels.WARN)
end

local function toggle_terminal()
  if invoke(config.integrations.terminal) then
    return
  end

  if has_command("ToggleTerm") then
    return vim.cmd("ToggleTerm")
  end

  if has_module("snacks") then
    local snacks = require("snacks")
    if snacks.terminal then
      return snacks.terminal()
    end
  end

  notify("No terminal backend is available", vim.log.levels.WARN)
end

local function toggle_problems()
  if invoke(config.integrations.problems) then
    return
  end

  if has_command("Trouble") then
    return vim.cmd("Trouble diagnostics toggle")
  end

  vim.diagnostic.setloclist()
  vim.cmd("lopen")
end

local function toggle_outline()
  if invoke(config.integrations.outline) then
    return
  end

  if has_command("AerialToggle") then
    return vim.cmd("AerialToggle!")
  end

  if has_command("Trouble") then
    return vim.cmd("Trouble symbols toggle focus=true")
  end

  notify("No outline backend is available", vim.log.levels.WARN)
end

local function toggle_tasks()
  if invoke(config.integrations.tasks) then
    return
  end

  if has_command("OverseerToggle") then
    return vim.cmd("OverseerToggle!")
  end

  notify("No task runner is available", vim.log.levels.WARN)
end

local function run_task(tag)
  if has_command("OverseerRun") then
    return vim.cmd("OverseerRun" .. (tag and (" " .. tag) or ""))
  end

  notify("No task runner is available", vim.log.levels.WARN)
end

local function task_action()
  if has_command("OverseerTaskAction") then
    return vim.cmd("OverseerTaskAction")
  end

  notify("No task runner is available", vim.log.levels.WARN)
end

local function agent_terminal()
  if invoke(config.integrations.agent_terminal) then
    return
  end

  local ok, panels = pcall(require, "config.workspace_panels")
  if not ok or type(panels.open_right_terminal_command) ~= "function" then
    return toggle_terminal()
  end

  local candidates = {
    { label = "Claude",        command = "claude --allow-dangerously-skip-permissions" },
    { label = "Claude (Ollama)", command = "ollama launch claude --model nemotron-cascade-2 -y -- --allow-dangerously-skip-permissions" },
    { label = "Copilot",       command = "copilot --model gpt-5.4 --reasoning-effort high --allow-all --remote" },
    { label = "Codex",         command = "codex --dangerously-bypass-approvals-and-sandbox" },
    { label = "Kilo",          command = "kilo --auto" },
    { label = "Aider",         command = "aider --yes-always" },
    { label = "Cline",         command = "cline --dangerously-skip-permissions" },
    { label = "OpenCode",      command = "opencode" },
    { label = "Agy (antigravity)", command = "agy antigravity" },
    { label = "Agy",           command = "agy --dangerously-skip-permissions" },
  }
  local available = {}

  for _, candidate in ipairs(candidates) do
    local bin = vim.split(candidate.command, " ")[1]
    bin = vim.split(bin, "/")[#vim.split(bin, "/")]
    if vim.fn.executable(bin) == 1 then
      available[#available + 1] = candidate
    end
  end

  if #available == 0 then
    panels.open_right_terminal_command()
    notify("No known CLI agent executable found; opened the right terminal", vim.log.levels.WARN)
    return
  end

  if #available == 1 then
    return panels.open_right_terminal_command(available[1].command)
  end

  vim.ui.select(available, {
    prompt = "Agent Terminal",
    format_item = function(item)
      return item.label .. " (" .. item.command .. ")"
    end,
  }, function(item)
    if item then
      panels.open_right_terminal_command(item.command)
    end
  end)
end

local function lsp_picker_or(method, picker_name, fallback, no_lsp_fallback)
  if not lsp_supports(method) then
    if no_lsp_fallback then
      return no_lsp_fallback()
    end
    return
  end

  if has_module("snacks") then
    local snacks = require("snacks")
    if snacks.picker and snacks.picker[picker_name] then
      return snacks.picker[picker_name]()
    end
  end

  return fallback()
end

local function goto_definition()
  return lsp_picker_or("textDocument/definition", "lsp_definitions", vim.lsp.buf.definition, function()
    fallback_normal("gd")
  end)
end

local function goto_references()
  return lsp_picker_or("textDocument/references", "lsp_references", vim.lsp.buf.references, search_word)
end

local function goto_implementation()
  return lsp_picker_or("textDocument/implementation", "lsp_implementations", vim.lsp.buf.implementation, function()
    goto_definition()
  end)
end

local function goto_type_definition()
  return lsp_picker_or("textDocument/typeDefinition", "lsp_type_definitions", vim.lsp.buf.type_definition, function()
    goto_definition()
  end)
end

local function goto_declaration()
  if lsp_supports("textDocument/declaration") then
    return vim.lsp.buf.declaration()
  end

  fallback_normal("gD")
end

local function hover()
  if lsp_supports("textDocument/hover") then
    return vim.lsp.buf.hover()
  end

  pcall(vim.cmd, "normal! K")
end

local function rename()
  if not lsp_supports("textDocument/rename") then
    return search_replace()
  end

  if has_command("IncRename") then
    return vim.cmd("IncRename " .. vim.fn.expand("<cword>"))
  end

  vim.lsp.buf.rename()
end

local function code_action()
  if lsp_supports("textDocument/codeAction") then
    return vim.lsp.buf.code_action()
  end

  notify("No LSP code-action provider is attached", vim.log.levels.WARN)
end

local function organize_imports()
  if not lsp_supports("textDocument/codeAction") then
    notify("No LSP code-action provider is attached", vim.log.levels.WARN)
    return
  end

  vim.lsp.buf.code_action({
    apply = true,
    context = {
      diagnostics = {},
      only = { "source.organizeImports" },
    },
  })
end

local function document_symbols()
  if has_module("snacks") and lsp_supports("textDocument/documentSymbol") then
    return require("snacks").picker.lsp_symbols()
  end

  toggle_outline()
end

local function workspace_symbols()
  if has_module("snacks") and lsp_supports("workspace/symbol") then
    return require("snacks").picker.lsp_workspace_symbols()
  end

  if lsp_supports("textDocument/documentSymbol") then
    return document_symbols()
  end

  return toggle_outline()
end

local function jump_back()
  feedkeys("<C-o>")
end

local function jump_forward()
  feedkeys("<C-i>")
end

local raw_actions = {
  quick_open = quick_open,
  buffers = buffers,
  recent_files = recent_files,
  projects = projects,
  command_palette = command_palette,
  notifications = notifications,
  jumps = jumps,
  quickfix_list = quickfix_list,
  search_project = search_project,
  search_word = search_word,
  search_replace = search_replace,
  todo_list = todo_list,
  git_file_history = git_file_history,
  toggle_explorer = toggle_explorer,
  toggle_terminal = toggle_terminal,
  toggle_problems = toggle_problems,
  toggle_outline = toggle_outline,
  toggle_tasks = toggle_tasks,
  run_task = function()
    run_task()
  end,
  run_build_task = function()
    run_task("BUILD")
  end,
  run_test_task = function()
    run_task("TEST")
  end,
  task_action = task_action,
  agent_terminal = agent_terminal,
  edit_history = edit_history,
  goto_definition = goto_definition,
  goto_references = goto_references,
  goto_implementation = goto_implementation,
  goto_type_definition = goto_type_definition,
  goto_declaration = goto_declaration,
  hover = hover,
  rename = rename,
  code_action = code_action,
  organize_imports = organize_imports,
  document_symbols = document_symbols,
  workspace_symbols = workspace_symbols,
  jump_back = jump_back,
  jump_forward = jump_forward,
}

local action_specs = {
  quick_open = { label = "Quick Open", command = "VSCodeQuickOpen", shortcuts = { "<C-p>", "<leader>ff" } },
  buffers = { label = "Buffers", command = "VSCodeBuffers", shortcuts = { "<leader>fb" } },
  recent_files = { label = "Recent Files", command = "VSCodeRecent", shortcuts = { "<leader>fr" } },
  projects = { label = "Projects", shortcuts = { "<leader>fp" } },
  command_palette = { label = "Command Palette", command = "VSCodeCommandPalette", shortcuts = { "<leader>sp" } },
  notifications = { label = "Notifications", shortcuts = { "<leader>n" } },
  jumps = { label = "Jumps", shortcuts = { "<leader>sj" } },
  quickfix_list = { label = "Quickfix", shortcuts = { "<leader>sq" } },
  search_project = { label = "Search in Files", command = "VSCodeSearch", shortcuts = { "<leader>/", "<leader>sg" } },
  search_word = { label = "Search Current Word", command = "VSCodeSearchWord", shortcuts = { "<leader>sw" } },
  search_replace = { label = "Search and Replace", command = "VSCodeSearchReplace", shortcuts = { "<leader>sr" } },
  todo_list = { label = "Todo List", shortcuts = { "<leader>st" } },
  git_file_history = { label = "Current File History", shortcuts = { "<leader>gf" } },
  toggle_explorer = { label = "Toggle Explorer", command = "VSCodeExplorer", shortcuts = { "<C-b>", "<leader>e" } },
  toggle_terminal = { label = "Toggle Terminal", command = "VSCodeTerminal" },
  toggle_problems = { label = "Toggle Problems", command = "VSCodeProblems", shortcuts = { "<leader>xx" } },
  toggle_outline = { label = "Toggle Outline", command = "VSCodeOutline", shortcuts = { "<leader>xo" } },
  toggle_tasks = { label = "Toggle Tasks", command = "VSCodeTasks", shortcuts = { "<leader>ot" } },
  run_task = { label = "Run Task", command = "VSCodeRunTask", shortcuts = { "<leader>or" } },
  run_build_task = { label = "Run Build Task", command = "VSCodeBuildTask", shortcuts = { "<leader>ob" } },
  run_test_task = { label = "Run Test Task", command = "VSCodeTestTask", shortcuts = { "<leader>oT" } },
  task_action = { label = "Task Action", command = "VSCodeTaskAction", shortcuts = { "<leader>oa" } },
  agent_terminal = { label = "Agent Terminal", command = "VSCodeAgentTerminal", shortcuts = { "<leader>a" } },
  edit_history = { label = "Edit History", command = "VSCodeEditHistory", shortcuts = { "<leader>su" } },
  goto_definition = { label = "Go to Definition", shortcuts = { "gd", "<F12>", "<C-LeftMouse>" } },
  goto_references = { label = "Find References", shortcuts = { "gr", "<S-F12>" } },
  goto_implementation = { label = "Go to Implementation", shortcuts = { "gI", "<M-F12>" } },
  goto_type_definition = { label = "Go to Type Definition", shortcuts = { "gy" } },
  goto_declaration = { label = "Go to Declaration", shortcuts = { "gD" } },
  hover = { label = "Hover", shortcuts = { "K" } },
  rename = { label = "Rename Symbol", shortcuts = { "<leader>cr", "<F2>" } },
  code_action = { label = "Code Action", shortcuts = { "<leader>ca" } },
  organize_imports = { label = "Organize Imports", command = "VSCodeOrganizeImports", shortcuts = { "<leader>co" } },
  document_symbols = { label = "Document Symbols", shortcuts = { "<leader>ss" } },
  workspace_symbols = { label = "Workspace Symbols", shortcuts = { "<leader>sS" } },
  jump_back = { label = "Go Back", shortcuts = { "<M-Left>" } },
  jump_forward = { label = "Go Forward", shortcuts = { "<M-Right>" } },
  usage_picker = { label = "Most Used Actions", command = "VSCodeUsage", shortcuts = { "<leader>sA" } },
  dock_help = { label = "Dock Help", command = "VSCodeDockHelp", shortcuts = { "<leader>si" } },
}

local actions = {}

local function setup_usage()
  local usage = require("vscode_productivity.usage")
  usage.setup(config.usage)

  raw_actions.usage_picker = function()
    usage.open_picker()
  end

  raw_actions.dock_help = function()
    if #dock_entries == 0 then
      notify("No dock entries are registered yet", vim.log.levels.INFO)
      return
    end

    local items = vim.deepcopy(dock_entries)
    table.sort(items, function(a, b)
      if a.side ~= b.side then
        return a.side < b.side
      end
      if (a.index or 0) ~= (b.index or 0) then
        return (a.index or 0) < (b.index or 0)
      end
      return (a.label or "") < (b.label or "")
    end)

    local function format_item(item)
      local side = item.side == "left" and "L" or "R"
      local shortcuts = item.shortcuts and #item.shortcuts > 0 and table.concat(item.shortcuts, ", ") or "-"
      local command = item.command and (":" .. item.command) or "-"
      return string.format("[%s] %s  %s | %s | %s", side, item.icon or " ", item.label or item.id, shortcuts, command)
    end

    if pcall(require, "snacks") and require("snacks").picker then
      return require("snacks").picker.select(items, {
        prompt = "Dock Icons",
        format_item = format_item,
      }, function(item)
        if item and item.run then
          item.run()
        end
      end)
    end

    vim.ui.select(items, {
      prompt = "Dock Icons",
      format_item = format_item,
    }, function(item)
      if item and item.run then
        item.run()
      end
    end)
  end

  for id, meta in pairs(action_specs) do
    actions[id] = function(...)
      usage.record(id)
      return raw_actions[id](...)
    end
    meta.run = actions[id]
  end

  usage.register_actions(action_specs)
end

local function create_user_commands()
  vim.api.nvim_create_user_command("VSCodeQuickOpen", actions.quick_open, { force = true })
  vim.api.nvim_create_user_command("VSCodeBuffers", actions.buffers, { force = true })
  vim.api.nvim_create_user_command("VSCodeRecent", actions.recent_files, { force = true })
  vim.api.nvim_create_user_command("VSCodeProjects", actions.projects, { force = true })
  vim.api.nvim_create_user_command("VSCodeCommandPalette", actions.command_palette, { force = true })
  vim.api.nvim_create_user_command("VSCodeNotifications", actions.notifications, { force = true })
  vim.api.nvim_create_user_command("VSCodeJumps", actions.jumps, { force = true })
  vim.api.nvim_create_user_command("VSCodeQuickfix", actions.quickfix_list, { force = true })
  vim.api.nvim_create_user_command("VSCodeSearch", actions.search_project, { force = true })
  vim.api.nvim_create_user_command("VSCodeSearchWord", actions.search_word, { force = true })
  vim.api.nvim_create_user_command("VSCodeSearchReplace", actions.search_replace, { range = true, force = true })
  vim.api.nvim_create_user_command("VSCodeTodo", actions.todo_list, { force = true })
  vim.api.nvim_create_user_command("VSCodeGitFileHistory", actions.git_file_history, { force = true })
  vim.api.nvim_create_user_command("VSCodeExplorer", actions.toggle_explorer, { force = true })
  vim.api.nvim_create_user_command("VSCodeProblems", actions.toggle_problems, { force = true })
  vim.api.nvim_create_user_command("VSCodeOutline", actions.toggle_outline, { force = true })
  vim.api.nvim_create_user_command("VSCodeTerminal", actions.toggle_terminal, { force = true })
  vim.api.nvim_create_user_command("VSCodeTasks", actions.toggle_tasks, { force = true })
  vim.api.nvim_create_user_command("VSCodeRunTask", actions.run_task, { force = true })
  vim.api.nvim_create_user_command("VSCodeBuildTask", actions.run_build_task, { force = true })
  vim.api.nvim_create_user_command("VSCodeTestTask", actions.run_test_task, { force = true })
  vim.api.nvim_create_user_command("VSCodeTaskAction", actions.task_action, { force = true })
  vim.api.nvim_create_user_command("VSCodeAgentTerminal", actions.agent_terminal, { force = true })
  vim.api.nvim_create_user_command("VSCodeEditHistory", actions.edit_history, { force = true })
  vim.api.nvim_create_user_command("VSCodeOrganizeImports", actions.organize_imports, { force = true })
  vim.api.nvim_create_user_command("VSCodeUsage", actions.usage_picker, { force = true })
  vim.api.nvim_create_user_command("VSCodeDockHelp", actions.dock_help, { force = true })
end

local function map(mode, lhs, rhs, desc, opts)
  opts = opts or {}
  opts.desc = desc
  vim.keymap.set(mode, lhs, rhs, opts)
end

local function set_global_maps()
  map("n", "<leader>ff", actions.quick_open, "Quick Open")
  map("n", "<leader>fb", actions.buffers, "Open Buffers")
  map("n", "<leader>fr", actions.recent_files, "Recent Files")
  map("n", "<leader>fp", actions.projects, "Projects")
  map("n", "<leader>sp", actions.command_palette, "Command Palette")
  map("n", "<leader>n", actions.notifications, "Notifications")
  map("n", "<leader>sj", actions.jumps, "Jumps")
  map("n", "<leader>sq", actions.quickfix_list, "Quickfix")
  map("n", "<leader>/", actions.search_project, "Search in Files")
  map("n", "<leader>sg", actions.search_project, "Search in Files")
  map({ "n", "x" }, "<leader>sw", actions.search_word, "Search Current Word")
  map({ "n", "x" }, "<leader>sr", actions.search_replace, "Search and Replace")
  map("n", "<leader>st", actions.todo_list, "Todo List")
  map("n", "<leader>e", actions.toggle_explorer, "Explorer")
  map("n", "<leader>gf", actions.git_file_history, "Current File History")
  map("n", "<leader>xx", actions.toggle_problems, "Problems")
  map("n", "<leader>xo", actions.toggle_outline, "Outline")
  map("n", "<leader>ss", actions.document_symbols, "Document Symbols")
  map("n", "<leader>sS", actions.workspace_symbols, "Workspace Symbols")
  map("n", "<leader>sA", actions.usage_picker, "Most Used Actions")
  map("n", "<leader>si", actions.dock_help, "Dock Help")
  map("n", "<leader>se", "<cmd>lua require('snacks').picker.icons()<CR>", "Icons (Emoji)")
  map("n", "<leader>su", actions.edit_history, "Edit History")
  map("n", "<leader>ot", actions.toggle_tasks, "Tasks")
  map("n", "<leader>or", actions.run_task, "Run Task")
  map("n", "<leader>ob", actions.run_build_task, "Run Build Task")
  map("n", "<leader>oT", actions.run_test_task, "Run Test Task")
  map("n", "<leader>oa", actions.task_action, "Task Action")
  map("n", "<leader>a", actions.agent_terminal, "Agent Terminal")
  map("n", "<D-a>", actions.agent_terminal, "Agent Terminal") -- Super/Command+A (GUI Neovim, not VS Code)
  map("n", "<leader>ca", actions.code_action, "Code Action")
  map({ "n", "x" }, "<C-.>", actions.code_action, "Code Action")
  map("n", "<leader>co", actions.organize_imports, "Organize Imports")
  map("n", "<leader>cr", actions.rename, "Rename")

  if not config.enable_vscode_keymaps then
    return
  end

  map("n", "<C-p>", actions.quick_open, "Quick Open")
  map("n", "<C-b>", actions.toggle_explorer, "Explorer")
  map("n", "<C-`>", actions.toggle_terminal, "Terminal")
  map("n", "<M-Left>", actions.jump_back, "Go Back")
  map("n", "<M-Right>", actions.jump_forward, "Go Forward")
  map("n", "<F2>", actions.rename, "Rename Symbol")
  map("n", "<F12>", actions.goto_definition, "Go to Definition")
  map("n", "<S-F12>", actions.goto_references, "Find References")
  map("n", "<M-F12>", actions.goto_implementation, "Go to Implementation")
  map("n", "<C-LeftMouse>", actions.goto_definition, "Go to Definition")
end

local function set_lsp_maps(event)
  local opts = { buffer = event.buf, silent = true }

  map("n", "gd", actions.goto_definition, "Go to Definition", opts)
  map("n", "gr", actions.goto_references, "Find References", opts)
  map("n", "gI", actions.goto_implementation, "Go to Implementation", opts)
  map("n", "gy", actions.goto_type_definition, "Go to Type Definition", opts)
  map("n", "gD", actions.goto_declaration, "Go to Declaration", opts)
  map("n", "K", actions.hover, "Hover", opts)
  map("n", "<leader>ca", actions.code_action, "Code Action", opts)
  map({ "n", "x" }, "<C-.>", actions.code_action, "Code Action", opts)
  map("n", "<leader>co", actions.organize_imports, "Organize Imports", opts)
  map("n", "<leader>cr", actions.rename, "Rename", opts)
  map("n", "<F12>", actions.goto_definition, "Go to Definition", opts)
  map("n", "<S-F12>", actions.goto_references, "Find References", opts)
  map("n", "<M-F12>", actions.goto_implementation, "Go to Implementation", opts)
  map("n", "<F2>", actions.rename, "Rename Symbol", opts)
  map("n", "<C-LeftMouse>", actions.goto_definition, "Go to Definition", opts)
end

function M.actions()
  return actions
end

function M.register_dock_entries(entries)
  dock_entries = vim.deepcopy(entries or {})
end

--- Open a toggleterm terminal pinned to its own edge.
--- Uses botright vsplit/split to create the terminal at the screen edge,
--- bypassing toggleterm's default open_split which can pile up terminals.
---@param id number Terminal ID
---@param size number Window size
---@param direction string "vertical" or "horizontal"
function M.toggle_term_edge(id, size, direction)
  local ok = pcall(require, "toggleterm")
  if not ok then return end
  local terms = require("toggleterm.terminal")
  local ui = require("toggleterm.ui")

  local term = terms.get(id)
  if term and term:is_open() then
    term:close()
    return
  end

  term = terms.get_or_create_term(id, nil, direction)

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.bo[buf].filetype
    if ft ~= "toggleterm" and ft ~= "neo-tree" then
      vim.api.nvim_set_current_win(win)
      break
    end
  end

  if direction == "vertical" then
    vim.cmd("botright vsplit | vertical resize " .. size)
  else
    vim.cmd("botright split | resize " .. size)
  end

  local win = vim.api.nvim_get_current_win()
  term.window = win

  if term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr) then
    vim.api.nvim_win_set_buf(win, term.bufnr)
    ui.switch_buf(term.bufnr)
  else
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(win, buf)
    term.bufnr = buf
    term:__add()
    term:spawn()
  end
  ui.hl_term(term)
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  setup_usage()
  create_user_commands()
  set_global_maps()

  -- Panel persistence (enabled by default)
  if config.panel_persistence ~= false then
    local persist_opts = type(config.panel_persistence) == "table"
      and config.panel_persistence
      or {}
    pcall(require("vscode_productivity.persistence").setup, persist_opts)
  end

  local group = vim.api.nvim_create_augroup("vscode_productivity_lsp", { clear = true })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = set_lsp_maps,
  })
end

return M
