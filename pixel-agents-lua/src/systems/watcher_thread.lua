-- Love2D thread entry point. Runs in a fresh Lua state.
-- Receives (dirs_csv, file_pattern, poll_ms) via thread:start(...) and pushes
-- { kind="line", dir, file, session_id, line } events to the
-- "agent_events" channel. Listens on "watcher_control" channel for "stop".
--
-- No globals leak across thread boundaries, so this file is self-contained:
-- it re-requires src.systems.watcher and constructs its own io_ops.

package.path = "./?.lua;./?/init.lua;" .. package.path

-- Love2D threads start with a minimal module set. Pull in what we need.
require("love.timer")
require("love.thread")

local args = { ... }
local dirs_csv = args[1] or ""
local file_pattern = args[2] or "%.jsonl$"
local poll_ms = tonumber(args[3]) or 500

local dirs = {}
for d in string.gmatch(dirs_csv, "([^|]+)") do
  dirs[#dirs + 1] = d
end

local watcher = require("src.systems.watcher")

-- ---------- Windows-friendly io_ops ----------

-- list_dir: use `dir /b /a-d` to list non-directory names, one per line.
local function shell_escape(s) return '"' .. s:gsub('"', '\\"') .. '"' end

local function list_dir(dir)
  local cmd = string.format('dir /b /a-d %s 2>nul', shell_escape(dir:gsub("/", "\\")))
  local names = {}
  local p = io.popen(cmd)
  if not p then return names end
  for line in p:lines() do
    if line and line ~= "" then
      names[#names + 1] = line
    end
  end
  p:close()
  return names
end

local function get_size(path)
  local f = io.open(path, "rb")
  if not f then return 0 end
  local size = f:seek("end") or 0
  f:close()
  return size
end

local function read_range(path, offset, n)
  local f = io.open(path, "rb")
  if not f then return "" end
  f:seek("set", offset)
  local data = f:read(n)
  f:close()
  return data or ""
end

local io_ops = {
  list_dir = list_dir,
  get_size = get_size,
  read_range = read_range,
}

-- ---------- main loop ----------

local out = love.thread.getChannel("agent_events")
local ctrl = love.thread.getChannel("watcher_control")

-- Cold-boot prime: start with state that ignores existing file contents.
-- Only lines appended after we start are reported as events.
local state = watcher.prime(dirs, file_pattern, io_ops)

local primed_files = 0
for _ in pairs(state.files) do primed_files = primed_files + 1 end

out:push({ kind = "hello", dirs = dirs, pattern = file_pattern, poll_ms = poll_ms, primed_files = primed_files })

while true do
  if ctrl:peek() == "stop" then break end

  local res = watcher.scanOnce(dirs, file_pattern, state, io_ops)
  state = res.state
  for _, nl in ipairs(res.new_lines) do
    out:push({
      kind = "line",
      dir = nl.dir,
      file = nl.file,
      session_id = nl.session_id,
      line = nl.line,
    })
  end

  love.timer.sleep(poll_ms / 1000)
end

out:push({ kind = "bye" })
