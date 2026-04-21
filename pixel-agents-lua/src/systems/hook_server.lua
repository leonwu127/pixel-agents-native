-- Main-thread wrapper around server_thread.lua. Handles:
--   * Generating the auth token
--   * Resolving ~/.pixel-agents-lua/server.json
--   * Starting/stopping the Love2D thread
--   * Exposing port/token to the caller once "hello" arrives
--
-- Usage (main thread):
--   local hs = hook_server.new({ user_home = "C:/Users/me", owner_pid = 1234 })
--   hs:start()
--   -- later, per frame:
--   for _, msg in ipairs(hs:drain()) do ... end
--   -- on quit:
--   hs:stop()

local M = {}
M.__index = M

local EVENTS_CHANNEL = "hook_events"
local CONTROL_CHANNEL = "server_control"
local SERVER_DIR = ".pixel-agents-lua"
local SERVER_FILENAME = "server.json"

-- Generate a 32-hex-char random token. We use `math.random` + os.time seeding;
-- this is not cryptographic but is sufficient to prevent trivial replay from
-- another local user without filesystem access to server.json.
local function generate_token()
  math.randomseed(os.time() + (os.clock() * 1e6))
  local buf = {}
  for i = 1, 32 do
    buf[i] = string.format("%x", math.random(0, 15))
  end
  return table.concat(buf)
end

function M.server_json_path(user_home)
  return string.format("%s/%s/%s", user_home, SERVER_DIR, SERVER_FILENAME)
end

-- Ensure the ~/.pixel-agents-lua directory exists. Uses plain lua since we
-- are on the main thread and love.filesystem can't write outside the save
-- dir.
local function ensure_dir(path)
  -- Try to open a sentinel; if that fails, mkdir via shell.
  local probe = io.open(path .. "/.probe", "wb")
  if probe then
    probe:close()
    os.remove(path .. "/.probe")
    return true
  end
  -- mkdir /p on Windows (cmd.exe). Silent on failure; the thread will push
  -- an error if it can't write server.json.
  os.execute(string.format('mkdir "%s" 2>nul', path:gsub("/", "\\")))
  return true
end

function M.new(opts)
  local self = setmetatable({
    user_home = opts.user_home,
    owner_pid = opts.owner_pid or 0,
    accept_timeout_ms = opts.accept_timeout_ms or 100,
    thread = nil,
    token = nil,
    port = nil,
    started = false,
  }, M)
  return self
end

function M:start()
  assert(self.user_home and #self.user_home > 0, "hook_server: user_home required")
  local dir = string.format("%s/%s", self.user_home, SERVER_DIR)
  ensure_dir(dir)

  local json_path = M.server_json_path(self.user_home)
  self.token = generate_token()

  self.thread = love.thread.newThread("src/systems/server_thread.lua")
  self.thread:start(json_path, self.token, self.accept_timeout_ms, self.owner_pid)
  self.started = true
  print(string.format("[hook_server] thread started (pid=%d, timeout=%dms)",
    self.owner_pid, self.accept_timeout_ms))
end

function M:stop()
  if not self.started then return end
  love.thread.getChannel(CONTROL_CHANNEL):push("stop")
  if self.thread then
    self.thread:wait()
    self.thread = nil
  end
  self.started = false
  print("[hook_server] stopped")
end

-- Drain all pending messages from the events channel. Absorbs "hello" to
-- populate self.port/self.ip. Returns the rest (mostly "event" messages) so
-- the scene can dispatch them.
function M:drain()
  local ch = love.thread.getChannel(EVENTS_CHANNEL)
  local out = {}
  while true do
    local msg = ch:pop()
    if not msg then break end
    if msg.kind == "hello" then
      self.port = msg.port
      self.ip = msg.ip
      print(string.format("[hook_server] listening on %s:%d", msg.ip, msg.port))
    elseif msg.kind == "bye" then
      print("[hook_server] thread exited")
    elseif msg.kind == "error" then
      print("[hook_server] error: " .. tostring(msg.message))
    else
      out[#out + 1] = msg
    end
  end
  return out
end

-- Surface thread-level crashes on next update.
function M:check_thread_error()
  if self.thread then
    local err = self.thread:getError()
    if err then
      print("[hook_server] thread crashed: " .. tostring(err))
      self.thread = nil
    end
  end
end

return M
