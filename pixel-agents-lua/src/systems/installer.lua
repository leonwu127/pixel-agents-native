-- Install/uninstall Pixel Agents hook entries in ~/.claude/settings.json.
--
-- Pure logic (no IO) lives here as table-in / table-out functions; the
-- caller supplies io_ops for file read/write + JSON encode/decode. This
-- keeps install/uninstall behavior unit-testable against a fake filesystem.
--
-- Idempotency: install() first removes any entries whose command string
-- contains our script filename (HOOK_SCRIPT_MARKER), then adds a fresh
-- entry per event. Running install() twice is a no-op on disk after the
-- first call (dedup via JSON round-trip).

local M = {}

-- Events we register hooks for. Order is preserved when writing settings.json
-- so diffs are stable.
M.HOOK_EVENTS = {
  "SessionStart",
  "SessionEnd",
  "Stop",
  "PermissionRequest",
  "Notification",
  "UserPromptSubmit",
  "PreToolUse",
  "PostToolUse",
  "PostToolUseFailure",
  "SubagentStart",
  "SubagentStop",
}

M.HOOK_SCRIPT_NAME = "claude-hook.ps1"
M.HOOK_TIMEOUT_SECONDS = 5

-- Identify one of our hook entries by checking if any inner `hooks[i].command`
-- string contains the script filename. This matches even if the absolute
-- path changed between installs.
function M.is_our_entry(entry)
  if type(entry) ~= "table" or type(entry.hooks) ~= "table" then return false end
  for _, h in ipairs(entry.hooks) do
    if type(h.command) == "string" and h.command:find(M.HOOK_SCRIPT_NAME, 1, true) then
      return true
    end
  end
  return false
end

-- Build the shell command Claude runs per event. On Windows this is executed
-- via cmd.exe, so we wrap the script path in double quotes.
function M.make_command(script_abs_path)
  return string.format(
    'powershell -NoProfile -ExecutionPolicy Bypass -File "%s"',
    script_abs_path
  )
end

-- Construct a single hook entry suitable for dropping into the settings.json
-- hooks[event] array.
function M.make_entry(script_abs_path)
  return {
    matcher = "",
    hooks = {
      {
        type    = "command",
        command = M.make_command(script_abs_path),
        timeout = M.HOOK_TIMEOUT_SECONDS,
      },
    },
  }
end

-- Returns a new settings table with our hook entries installed for every
-- event in HOOK_EVENTS. Caller-owned settings is not mutated. Dedups by
-- removing any existing our-entries first, so repeated installs stay
-- idempotent.
function M.merge_install(settings, script_abs_path)
  local out = {}
  -- Shallow-copy top-level fields
  if type(settings) == "table" then
    for k, v in pairs(settings) do out[k] = v end
  end
  local hooks = {}
  if type(out.hooks) == "table" then
    for k, v in pairs(out.hooks) do hooks[k] = v end
  end

  for _, event in ipairs(M.HOOK_EVENTS) do
    local entries = hooks[event]
    local filtered = {}
    if type(entries) == "table" then
      for _, e in ipairs(entries) do
        if not M.is_our_entry(e) then filtered[#filtered + 1] = e end
      end
    end
    filtered[#filtered + 1] = M.make_entry(script_abs_path)
    hooks[event] = filtered
  end

  out.hooks = hooks
  return out
end

-- Returns a new settings table with our hook entries removed. Empty event
-- arrays are deleted; if the whole `hooks` object becomes empty, it is
-- deleted too, so uninstall leaves the file in the same shape as before we
-- touched it.
function M.merge_uninstall(settings)
  local out = {}
  if type(settings) == "table" then
    for k, v in pairs(settings) do out[k] = v end
  end
  if type(out.hooks) ~= "table" then return out end

  local hooks = {}
  for k, v in pairs(out.hooks) do hooks[k] = v end

  for event, entries in pairs(hooks) do
    if type(entries) == "table" then
      local filtered = {}
      for _, e in ipairs(entries) do
        if not M.is_our_entry(e) then filtered[#filtered + 1] = e end
      end
      if #filtered == 0 then
        hooks[event] = nil
      else
        hooks[event] = filtered
      end
    end
  end

  local any = false
  for _ in pairs(hooks) do any = true; break end
  if any then out.hooks = hooks else out.hooks = nil end
  return out
end

-- Returns true if every event in HOOK_EVENTS already has one of our entries.
function M.is_installed(settings)
  if type(settings) ~= "table" or type(settings.hooks) ~= "table" then
    return false
  end
  for _, event in ipairs(M.HOOK_EVENTS) do
    local entries = settings.hooks[event]
    if type(entries) ~= "table" then return false end
    local found = false
    for _, e in ipairs(entries) do
      if M.is_our_entry(e) then found = true; break end
    end
    if not found then return false end
  end
  return true
end

-- ---------- Thin IO-bound wrapper ----------
-- The caller (main.lua) supplies an io_ops table:
--   io_ops.read_file(path)         -> string | nil
--   io_ops.write_file(path, data)  -> ok, err    (atomic: tmp + rename)
--   io_ops.exists(path)            -> boolean
--   io_ops.ensure_parent_dir(path) -> ok
--   io_ops.copy_file(src, dst)     -> ok, err
--   json.encode(tbl) / json.decode(str)

function M.install(io_ops, json, settings_path, script_abs_path)
  local current = {}
  if io_ops.exists(settings_path) then
    local raw = io_ops.read_file(settings_path)
    if raw and #raw > 0 then
      local ok, parsed = pcall(json.decode, raw)
      if ok and type(parsed) == "table" then current = parsed end
    end
  end
  local updated = M.merge_install(current, script_abs_path)
  io_ops.ensure_parent_dir(settings_path)
  local encoded = json.encode(updated)
  return io_ops.write_file(settings_path, encoded)
end

function M.uninstall(io_ops, json, settings_path)
  if not io_ops.exists(settings_path) then return true end
  local raw = io_ops.read_file(settings_path)
  if not raw or #raw == 0 then return true end
  local ok, parsed = pcall(json.decode, raw)
  if not ok or type(parsed) ~= "table" then return true end
  local updated = M.merge_uninstall(parsed)
  local encoded = json.encode(updated)
  return io_ops.write_file(settings_path, encoded)
end

-- ---------- Real-filesystem io_ops factory (for main.lua) ----------
-- Builds an io_ops table backed by Lua's standard io library. Safe to use on
-- the main thread. Writes go through a tmp+rename cycle for atomicity; on
-- Windows `os.rename` fails if the destination exists, so we `os.remove`
-- first — the write is effectively single-writer, so the race window is
-- inconsequential.

local function file_exists(path)
  local f = io.open(path, "rb")
  if not f then return false end
  f:close()
  return true
end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local data = f:read("*a")
  f:close()
  return data
end

local function ensure_parent_dir(path)
  local dir = path:match("^(.+)[/\\][^/\\]+$")
  if not dir then return true end
  -- Use platform-appropriate mkdir. Silent on failure; write_file will fail
  -- loudly if the directory genuinely can't be created.
  local win_dir = dir:gsub("/", "\\")
  os.execute(string.format('mkdir "%s" 2>nul', win_dir))
  return true
end

local function atomic_write(path, data)
  ensure_parent_dir(path)
  local tmp = path .. ".pixel-agents-tmp"
  local f, err = io.open(tmp, "wb")
  if not f then return false, err end
  f:write(data)
  f:close()
  os.remove(path)
  local ok, rerr = os.rename(tmp, path)
  if not ok then
    os.remove(tmp)
    return false, rerr
  end
  return true
end

local function copy_file(src, dst)
  local data = read_file(src)
  if not data then return false, "source not readable" end
  return atomic_write(dst, data)
end

function M.make_io_ops()
  return {
    exists = file_exists,
    read_file = read_file,
    write_file = atomic_write,
    ensure_parent_dir = function(path) return ensure_parent_dir(path) end,
    copy_file = copy_file,
  }
end

-- ---------- Path helpers ----------

function M.claude_settings_path(user_home)
  return user_home .. "/.claude/settings.json"
end

function M.hook_script_dest(user_home)
  return user_home .. "/.pixel-agents-lua/hooks/" .. M.HOOK_SCRIPT_NAME
end

-- Copy the PowerShell hook template from the game source dir to the user's
-- ~/.pixel-agents-lua/hooks/ directory. Returns (ok, dest_path, err).
function M.install_hook_script(io_ops, game_source_dir, user_home)
  local src = game_source_dir .. "/hooks/" .. M.HOOK_SCRIPT_NAME
  local dst = M.hook_script_dest(user_home)
  local ok, err = io_ops.copy_file(src, dst)
  return ok, dst, err
end

return M
