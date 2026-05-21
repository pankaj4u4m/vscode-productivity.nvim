# vscode-productivity.nvim

A **Neovim** compatibility layer for VS Code-style workflows. Provides quick open, project search, LSP navigation, terminal management, task running, AI agent launcher, and a clickable VS Code-inspired statusline — all backed by the community plugins you already use.

> **Works with any Neovim setup** — LazyVim, AstroNvim, NvChad, or your own from scratch.
> The only framework-specific part is the optional statusline module, which requires Heirline.

---

## What's included

| Module | File | Requires |
|---|---|---|
| **Productivity actions** (core) | `lua/vscode_productivity/init.lua` | Nothing — detects backend plugins at runtime |
| **Usage tracking** | `lua/vscode_productivity/usage.lua` | Nothing — bundled with the core |
| **Statusline icons** (optional) | `lua/vscode_productivity/statusline.lua` | `rebelot/heirline.nvim` |

### Statusline: AstroNvim vs standalone

The statusline module works with **any Heirline-based statusline**, not just AstroNvim. It merges VS Code button icons into whatever statusline you already have (AstroNvim's default, your custom one, etc.).

- **AstroNvim users**: just call `.overrides()` — it automatically preserves AstroNvim's existing components.
- **Standalone Heirline users**: same API, just pass in your own base statusline.

---

## Features

- **VS Code productivity actions**: quick open, command palette, search, replace, git, tasks, etc.
- **AI agent terminal**: pick and launch any CLI agent (Claude, Copilot, Codex, Kilo, Aider, Cline, OpenCode, Agy, etc.)
- **Clickable statusline icons** (optional Heirline module)
- **Usage tracking**: tracks your most-used actions with a frequency-sorted picker
- **Dock help**: discover all registered icons and their shortcuts via a picker
- **All backends are optional**: automatically detects and uses snacks.nvim / telescope.nvim / fzf-lua / neo-tree.nvim / trouble.nvim / overseer.nvim / toggleterm.nvim / aerial.nvim at runtime

---

## Installation

### With lazy.nvim (any framework)

```lua
{
  "pankaj4u4m/vscode-productivity.nvim",
  lazy = false,
  dependencies = {
    -- All optional — only install what you use
    "folke/snacks.nvim",           -- pickers, git status, notifications
    "nvim-neo-tree/neo-tree.nvim", -- file explorer
    "folke/trouble.nvim",          -- problems / quickfix / outline
    "MagicDuck/grug-far.nvim",     -- search and replace
    "stevearc/overseer.nvim",      -- task runner
  },
  opts = {
    integrations = {
      -- explorer = function() ... end,
      -- terminal = function() ... end,
      -- problems = function() ... end,
      -- tasks = function() ... end,
      -- agent_terminal = function() ... end,
    },
  },
  config = function(_, opts)
    require("vscode_productivity").setup(opts)
  end,
}
```

### With statusline icons (Heirline — works with AstroNvim, LazyVim, or standalone)

Add the VS Code-style statusline buttons to your Heirline:

```lua
{
  "rebelot/heirline.nvim",
  dependencies = { "pankaj4u4m/vscode-productivity.nvim" },
  opts = require("vscode_productivity.statusline").overrides(),
}
```

That's it. Whether you use AstroNvim, LazyVim's Heirline, or your own setup, calling `.overrides()` injects the VS Code buttons while preserving your existing statusline components.

### Via git submodule (for dotfiles)

```bash
git submodule add https://github.com/pankaj4u4m/vscode-productivity.nvim \
  .config/nvim/packages/vscode-productivity.nvim
git submodule update --init --recursive
```

```lua
{
  dir = vim.fn.stdpath("config") .. "/packages/vscode-productivity.nvim",
  name = "vscode-productivity.nvim",
  lazy = false,
  dependencies = {
    "folke/snacks.nvim",
    "nvim-neo-tree/neo-tree.nvim",
    "folke/trouble.nvim",
    "MagicDuck/grug-far.nvim",
    "stevearc/overseer.nvim",
  },
  opts = { integrations = { ... } },
  config = function(_, opts)
    require("vscode_productivity").setup(opts)
  end,
}
```

---

## Configuration

### Core plugin (`setup()`)

```lua
require("vscode_productivity").setup({
  -- VS Code-style keymaps (<C-p>, <C-b>, <C-`>, <F2>, <F12>, etc.)
  enable_vscode_keymaps = true,

  -- Custom integration callbacks (override automatic backend detection)
  integrations = {
    explorer = nil,      -- function() … end
    terminal = nil,      -- function() … end
    problems = nil,      -- function() … end
    outline = nil,       -- function() … end
    tasks = nil,         -- function() … end
    agent_terminal = nil, -- function() … end
  },

  -- Usage tracking
  usage = {
    state_file = function()
      return vim.fn.stdpath("state") .. "/vscode-productivity/usage.json"
    end,
  },
})
```

### Statusline (`overrides()`)

```lua
-- Custom icon overrides
require("vscode_productivity.statusline").overrides({
  icons = {
    explorer = "󰙅",
    quick_open = "󰈞",
    terminal = "",
    tasks = "󱂬",
    debug = "",
  },
})

-- Custom button entries (replaces defaults)
require("vscode_productivity.statusline").overrides({
  left_entries = {
    {
      name = "my_tool",
      label = "My Tool",
      icon = "",
      callback = function() print("Hello!") end,
      is_active = function() return false end,
    },
  },
  right_entries = nil, -- passes nil = keep defaults
})
```

---

## AstroNvim integration example

This plugin works out of the box with AstroNvim. Here's a reference config showing how to wire everything together:

### `lua/plugins/vscode-productivity.lua`

```lua
return {
  {
    dir = vim.fn.stdpath("config") .. "/packages/vscode-productivity.nvim",
    name = "vscode-productivity.nvim",
    lazy = false,
    dependencies = {
      "folke/snacks.nvim",
      "nvim-neo-tree/neo-tree.nvim",
      "folke/trouble.nvim",
      "MagicDuck/grug-far.nvim",
      "stevearc/overseer.nvim",
    },
    opts = {
      integrations = {
        explorer = function()
          require("neo-tree.command").execute({ toggle = true, source = "filesystem", position = "left" })
        end,
        terminal = function()
          _G.toggle_term_edge(1, 25, "horizontal")
        end,
        problems = function()
          if vim.fn.exists(":Trouble") == 2 then
            vim.cmd("Trouble diagnostics toggle")
          else
            vim.diagnostic.setloclist()
            vim.cmd("lopen")
          end
        end,
        tasks = function()
          vim.cmd("OverseerToggle!")
        end,
        agent_terminal = function()
          -- see plugin config in dotfiles for full agent list
          vim.cmd("VSCodeAgentTerminal")
        end,
      },
    },
    config = function(_, opts)
      require("vscode_productivity").setup(opts)
    end,
  },
}
```

### `lua/plugins/vscode-statusline.lua`

```lua
return {
  "rebelot/heirline.nvim",
  opts = require("vscode_productivity.statusline").overrides(),
  dependencies = { "vscode-productivity.nvim" },
}
```

### `lua/polish.lua` (AstroNvim's post-plugin hook) — optional

> **You don't need this file for the statusline or plugin to work.**
> The plugin and statusline are fully self-contained.
> This is just extra quality-of-life — it saves which panels you had open and
> restores them after restart (like VS Code's window state persistence).

This lives in **your own config**, not in the plugin. The `toggle_term_edge()` helper it uses is already exported by the plugin.

```lua
-- Panel state persistence — saves which VS Code panels are open on exit,
-- restores them on next start. Uses a JSON file alongside sessions.
local state_file = vim.fn.stdpath("state") .. "/vscode_panels.json"
local function open_toggle_terminal(id, size, direction)
  require("toggleterm").toggle(id, size, nil, direction)
end

-- Save panel state on exit
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = vim.api.nvim_create_augroup("VSCodePanelSave", { clear = true }),
  callback = function()
    local state = { explorer = false, problems = false,
      terminal_right = false, outline = false, terminal = false }
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
      if ft == "neo-tree" then state.explorer = true end
      if ft == "trouble" then state.problems = true end
      if ft == "aerial" then state.outline = true end
      if ft == "toggleterm" then
        local id = vim.b[vim.api.nvim_win_get_buf(win)].toggleterm_id
        if id == 2 then state.terminal_right = true
        else state.terminal = true end
      end
    end
    vim.fn.mkdir(vim.fn.fnamemodify(state_file, ":h"), "p")
    vim.fn.writefile({ vim.json.encode(state) }, state_file)
  end,
})

-- Restore panel state on start
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("VSCodePanelRestore", { clear = true }),
  callback = function()
    vim.schedule(function()
      if vim.fn.filereadable(state_file) ~= 1 then return end
      local ok, state = pcall(vim.json.decode, table.concat(
        vim.fn.readfile(state_file), "\n"))
      if not ok then return end
      if state.explorer then vim.cmd("VSCodeExplorer") end
      if state.terminal then vim.cmd("VSCodeTerminal") end
      if state.problems then vim.cmd("VSCodeProblems") end
      if state.outline then vim.cmd("VSCodeOutline") end
      if state.terminal_right then
        pcall(require("vscode_productivity").toggle_term_edge, 2, 80, "vertical")
      end
    end)
  end,
})
```

---

## Commands

| Command | Action |
|---|---|
| `:VSCodeQuickOpen` | Quick open files |
| `:VSCodeBuffers` | List open buffers |
| `:VSCodeRecent` | Recent files |
| `:VSCodeProjects` | Project picker |
| `:VSCodeCommandPalette` | Command palette |
| `:VSCodeNotifications` | Notification history |
| `:VSCodeJumps` | Jump history |
| `:VSCodeQuickfix` | Quickfix list |
| `:VSCodeSearch` | Search in files |
| `:VSCodeSearchWord` | Search current word |
| `:VSCodeSearchReplace` | Search and replace |
| `:VSCodeTodo` | TODO comments |
| `:VSCodeGitFileHistory` | Git file history |
| `:VSCodeExplorer` | Toggle explorer |
| `:VSCodeProblems` | Toggle problems |
| `:VSCodeOutline` | Toggle outline |
| `:VSCodeTerminal` | Toggle terminal |
| `:VSCodeTerminalRight` | Toggle right terminal |
| `:VSCodeTasks` | Toggle tasks |
| `:VSCodeRunTask` | Run task |
| `:VSCodeBuildTask` | Run build task |
| `:VSCodeTestTask` | Run test task |
| `:VSCodeTaskAction` | Task action |
| `:VSCodeAgentTerminal` | AI agent terminal |
| `:VSCodeEditHistory` | Edit/undo history |
| `:VSCodeOrganizeImports` | Organize imports |
| `:VSCodeUsage` | Most used actions |
| `:VSCodeDockHelp` | Dock icon help |

## Keymaps

### VS Code-style (optional, enabled via `enable_vscode_keymaps = true`)

| Keys | Action |
|---|---|
| `<C-p>` | Quick open |
| `<C-b>` | Toggle explorer |
| `<C-\`>` | Toggle terminal |
| `<M-Left>` | Jump back |
| `<M-Right>` | Jump forward |
| `<F2>` | Rename symbol |
| `<F12>` | Go to definition |
| `<S-F12>` | Find references |
| `<M-F12>` | Go to implementation |
| `<C-LeftMouse>` | Go to definition |

### Leader keymaps (always active)

| Keys | Action |
|---|---|
| `<leader>ff` | Quick open |
| `<leader>fb` | Buffers |
| `<leader>fr` | Recent files |
| `<leader>fp` | Projects |
| `<leader>sp` | Command palette |
| `<leader>/` | Search in files |
| `<leader>sg` | Search in files |
| `<leader>sr` | Search and replace |
| `<leader>sw` | Search current word |
| `<leader>e` | Explorer |
| `<leader>xx` | Problems |
| `<leader>xo` | Outline |
| `<leader>ss` | Document symbols |
| `<leader>sS` | Workspace symbols |
| `<leader>st` | TODO list |
| `<leader>sj` | Jumps |
| `<leader>sq` | Quickfix |
| `<leader>su` | Edit history |
| `<leader>si` | Dock help |
| `<leader>sA` | Most used actions |
| `<leader>n` | Notifications |
| `<leader>ot` | Tasks |
| `<leader>or` | Run task |
| `<leader>ob` | Build task |
| `<leader>oT` | Test task |
| `<leader>oa` | Task action |
| `<leader>a` | Agent terminal |
| `<leader>ca` | Code action |
| `<leader>co` | Organize imports |
| `<leader>cr` | Rename |
| `<leader>gf` | Git file history |
| `<leader>gt` | Git status |

## Backend detection

The plugin detects installed plugins at runtime and dispatches to the first available:

| Feature | Priority |
|---|---|
| **Picker** | snacks.nvim → telescope.nvim → fzf-lua |
| **Explorer** | custom callback → neo-tree.nvim → snacks.nvim |
| **Terminal** | custom callback → toggleterm.nvim → snacks.nvim |
| **Problems** | custom callback → trouble.nvim → location list |
| **Outline** | custom callback → aerial.nvim → trouble.nvim |
| **Tasks** | custom callback → overseer.nvim |
| **Search/replace** | grug-far.nvim |
| **Statusline** | Heirline (via optional statusline module) |

## Structure

```
vscode-productivity.nvim/
├── lua/
│   └── vscode_productivity/
│       ├── init.lua          # Core: setup(), actions(), commands, keymaps
│       ├── usage.lua         # Usage tracking and most-used picker
│       └── statusline.lua    # Heirline statusline icon overrides (optional)
├── plugin/
│   └── vscode-productivity.lua  # Auto-load: creates commands on startup
├── README.md
└── LICENSE
```

## License

MIT
