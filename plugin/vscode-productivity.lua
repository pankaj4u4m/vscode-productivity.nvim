-- vscode-productivity.nvim
-- Auto-load entry point. Creates user commands so they are available even
-- without calling setup() explicitly (e.g. when not using lazy.nvim).
--
-- For full functionality, call require("vscode_productivity").setup(opts)
-- in your Neovim config.

local function is_loaded(name)
  return package.loaded[name] ~= nil
end

-- Only create commands if the module hasn't been set up yet (avoids double
-- registration when lazy.nvim calls setup() in its config function).
if not is_loaded("vscode_productivity") then
  local ok, mod = pcall(require, "vscode_productivity")
  if ok and mod and mod.setup then
    mod.setup()
  else
    -- Defer to VimEnter if not ready (packpath not yet set, etc.)
    vim.api.nvim_create_autocmd("VimEnter", {
      once = true,
      callback = function()
        local ok2, mod2 = pcall(require, "vscode_productivity")
        if ok2 and mod2 and mod2.setup then
          mod2.setup()
        end
      end,
    })
  end
end
