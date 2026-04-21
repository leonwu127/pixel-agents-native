-- User config loaded from `%USERPROFILE%\.pixel-agents-lua\config.lua`.
-- Optional. Falls back to built-in defaults.
--
-- Config file shape (all fields optional):
--   return {
--     workspacePath = "C:\\path\\to\\project",   -- overrides auto-detection
--     layoutFile    = "layouts/mvp_v0.lua",      -- relative to game source dir
--     pollMs        = 500,
--   }
--
-- Fields computed at runtime (not in the config file):
--   projectHash : derived from workspacePath per Claude's naming rule
--                 [:/\] -> -
--   claudeDir   : %USERPROFILE%\.claude\projects\<projectHash>

local assertf = require("src.assert").assertf

local M = {}

local DEFAULTS = {
  layoutFile    = "layouts/mvp_v0.lua",
  pollMs        = 500,
  hooksEnabled  = false,  -- opt-in: modifies ~/.claude/settings.json when true
}

function M.project_hash(path)
  assertf(type(path) == "string" and #path > 0, "project_hash: path required")
  return (path:gsub("[:\\/]", "-"))
end

-- Return the user's home directory (Windows: %USERPROFILE%).
function M.user_home()
  return os.getenv("USERPROFILE") or os.getenv("HOME") or ""
end

-- Find the config file path. Nil if it does not exist.
function M.find_config_file()
  local home = M.user_home()
  if home == "" then return nil end
  local path = home .. "/.pixel-agents-lua/config.lua"
  local f = io.open(path, "rb")
  if not f then return nil end
  f:close()
  return path
end

-- Load user config, applying defaults. `workspace_default` is the
-- workingDir from Love2D (used when config does not specify workspacePath).
function M.load(workspace_default)
  local conf = {
    workspacePath = workspace_default,
    layoutFile    = DEFAULTS.layoutFile,
    pollMs        = DEFAULTS.pollMs,
    hooksEnabled  = DEFAULTS.hooksEnabled,
  }

  local path = M.find_config_file()
  if path then
    local chunk, err = loadfile(path)
    assertf(chunk, "config: failed to load %s: %s", tostring(path), tostring(err))
    local ok, user = pcall(chunk)
    assertf(ok, "config: error executing %s: %s", tostring(path), tostring(user))
    assertf(type(user) == "table", "config: must return a table")
    if user.workspacePath then conf.workspacePath = user.workspacePath end
    if user.layoutFile then conf.layoutFile = user.layoutFile end
    if user.pollMs then conf.pollMs = user.pollMs end
    if user.hooksEnabled ~= nil then conf.hooksEnabled = user.hooksEnabled end
  end

  assertf(conf.workspacePath and #conf.workspacePath > 0, "config: workspacePath required")
  conf.projectHash = M.project_hash(conf.workspacePath)
  conf.claudeDir = string.format("%s/.claude/projects/%s", M.user_home(), conf.projectHash)

  return conf
end

return M
