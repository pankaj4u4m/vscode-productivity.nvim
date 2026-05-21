# vscode-productivity.nvim

A Neovim compatibility layer for VS Code-style workflows. Provides quick open, project search, LSP navigation, terminal management, task running, AI agent launcher, and a VS Code-inspired clickable statusline — all backed by the community plugins you already use.

It **detects and dispatches** to existing plugins for the heavy lifting and only owns the glue:
- Picker → snacks.nvim / telescope.nvim / fzf-lua
- Explorer → neo-tree.nvim or custom callback
- Search/replace → grug-far.nvim
- Problems → trouble.nvim or location list
- Outline → aerial.nvim or trouble.nvim
- Terminal → toggleterm.nvim or custom callback
- Tasks → overseer.nvim or custom callback
- Statusline → Heirline (AstroNvim or standalone)

---

## ✨ Features

- **VS Code productivity actions**: quick open, command palette, search, replace, git, tasks, etc.
- **AI agent terminal**: pick and launch any CLI agent (Claude, Copilot, Codex, Kilo, Aider, Cline, OpenCode, etc.)
- **Clickable statusline icons** (optional): add VS Code-style buttons to your Heirline statusline
- **Usage tracking**: tracks your most-used actions with a frequency-sorted picker
- **Dock help**: discover all registered icons and their shortcuts via a picker
- **Lazy, zero-dependency core**: detects what plugins are installed and dispatches accordingly
- **All backends are optional**: bring your own picker, explorer, terminal, etc.

---

## 📦 Installation

### lazy.nvim

```lua
{
  "pankaj4u4m/vscode-productivity.nvim",
  lazy = false,
  dependencies = {
    "folke/snacks.nvim",           -- optional, for pickers
    "nvim-neo-tree/neo-tree.nvim", -- optional, for explorer
    "folke/trouble.nvim",          -- optional, for problems/outline
    "MagicDuck/grug-far.nvim",     -- optional, for search/replace
    "stevearc/overseer.nvim",      -- optional, for tasks
  },
  opts = {
    -- Integration callbacks (optional)
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

### With statusline icons (AstroNvim)

```lua
-- Add the clickable VS Code statusline icons to your Heirline
{
  "rebelot/heirline.nvim",
  opts = require("vscode_productivity.statusline").overrides(),
  dependencies = {
    "pankaj4u4m/vscode-productivity.nvim",
  },
}
```

### With statusline icons (standalone Heirline)

```lua
{
  "rebelot/heirline.nvim",
  opts = function(_, opts)
    opts = require("vscode_productivity.statusline").overrides({})(_, opts)
    -- Customize your own statusline components here
    return opts
  end,
  dependencies = {
    "pankaj4u4m/vscode-productivity.nvim",
  },
}
```

### Via git submodule (for dotfiles)

```bash
# Add to your dotfiles repo
git submodule add https://github.com/pankaj4u4m/vscode-productivity.nvim \
  .config/nvim/packages/vscode-productivity.nvim

# Initialize and clone
git submodule update --init --recursive
```

Then in your lazy.nvim config:

```lua
{
  dir = vim.fn.stdpath("config") .. "/packages/vscode-productivity.nvim",
  name = "vscode-productivity.nvim",
  lazy = false,
  dependencies = { "folke/snacks.nvim", "nvim-neo-tree/neo-tree.nvim", ... },
  opts = { ... },
  config = function(_, opts)
    require("vscode_productivity").setup(opts)
  end,
}
```

### AstroNvim community recipe

You can also add it as an AstroNvim community recipe import. See [astrocommunity](https://github.com/AstroNvim/astrocommunity).

---

## ⚙️ Configuration

The `setup()` function accepts an optional table:

```lua
require("vscode_productivity").setup({
  -- Enable VS Code-style keymaps (C-p, C-b, C-`, F2, F12, etc.)
  enable_vscode_keymaps = true,

  -- Custom integration callbacks (override automatic detection)
  integrations = {
    -- Explorer: function to toggle file explorer
    explorer = nil,
    -- Terminal: function to toggle terminal
    terminal = nil,
    -- Problems: function to toggle diagnostics panel
    problems = nil,
    -- Outline: function to toggle symbol outline
    outline = nil,
    -- Tasks: function to toggle task list
    tasks = nil,
    -- Agent terminal: function to launch AI agent
    agent_terminal = nil,
  },

  -- Usage tracking configuration
  usage = {
    -- File path for usage state JSON
    state_file = function()
      return vim.fn.stdpath("state") .. "/vscode-productivity/usage.json"
    end,
  },
})
```

### Statusline icon overrides

```lua
require("vscode_productivity.statusline").overrides({
  icons = {
    explorer = "󰙅",
    quick_open = "󰈞",
    terminal = "",
    tasks = "󱂬",
    debug = "",
    -- ... all entries have customizable icons
  },
})
```

### Custom statusline entries

```lua
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
  right_entries = {
    -- ... or pass nil to use defaults
  },
})
```

---

## 🎮 Commands

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

## ⌨️ Keymaps

### VS Code-style (optional, enabled by default)

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

### Leader keymaps

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

---

## 🔌 Backend Support

### Picker
Detects and uses the first available of:
1. `snacks.nvim` (preferred)
2. `telescope.nvim`
3. `fzf-lua`

### Explorer
1. Custom callback via `integrations.explorer`
2. `neo-tree.nvim`
3. `snacks.nvim` explorer

### Terminal
1. Custom callback via `integrations.terminal`
2. `toggleterm.nvim` (`:ToggleTerm`)
3. `snacks.nvim` terminal

### Problems
1. Custom callback via `integrations.problems`
2. `trouble.nvim` (`:Trouble diagnostics toggle`)
3. Location list fallback (`vim.diagnostic.setloclist()` + `:lopen`)

### Outline
1. Custom callback via `integrations.outline`
2. `aerial.nvim` (`:AerialToggle!`)
3. `trouble.nvim` (`:Trouble symbols toggle`)

### Tasks
1. Custom callback via `integrations.tasks`
2. `overseer.nvim` (`:OverseerToggle!`)

---

## 📁 Structure

```
vscode-productivity.nvim/
├── lua/
│   └── vscode_productivity/
│       ├── init.lua          # Main module: setup(), actions(), commands, keymaps
│       ├── usage.lua         # Usage tracking and most-used picker
│       └── statusline.lua    # Heirline statusline icon overrides (optional)
├── plugin/
│   └── vscode-productivity.lua  # Auto-load: creates commands on startup
├── README.md
└── LICENSE
```

---

## 📄 License

MIT
