-- Love2D thread: runs an HTTP server on 127.0.0.1:<random> that accepts hook
-- events from Claude Code hook scripts and forwards them to the main thread
-- via the `hook_events` channel.
--
-- Thread args (all strings, passed via thread:start):
--   server_json_path : absolute path to write ~/.pixel-agents-lua/server.json
--   auth_token       : Bearer token required on hook POSTs
--   accept_timeout_ms : socket receive timeout for polling (default 100)
--   owner_pid        : PID of the Love2D main process (for server.json + ownership check)
--
-- Channels:
--   hook_events (out)   : { kind = "hello", port, pid } | { kind = "event", providerId, event } | { kind = "bye" }
--   server_control (in) : "stop"
--
-- Shutdown protocol:
--   1. main pushes "stop" to server_control
--   2. thread wakes within accept_timeout_ms, closes the listen socket
--   3. thread deletes server.json (only if our PID matches)
--   4. pushes { kind = "bye" } and exits

package.path = "./?.lua;./?/init.lua;" .. package.path

require("love.timer")
require("love.thread")

local socket = require("socket")
local http = require("src.systems.http")
local json_decode = require("src.vendor.json").decode

local args = { ... }
local server_json_path = args[1] or ""
local auth_token = args[2] or ""
local accept_timeout_ms = tonumber(args[3]) or 100
local owner_pid = tonumber(args[4]) or 0

local out = love.thread.getChannel("hook_events")
local ctrl = love.thread.getChannel("server_control")

local function push_error(msg)
  out:push({ kind = "error", message = tostring(msg) })
end

-- ---------- Atomic write server.json ----------

local function write_server_json(path, port, pid)
  local payload = http.json_encode({
    port = tonumber(port) or 0,
    pid = tonumber(pid) or 0,
    token = auth_token,
    startedAt = os.time() * 1000,
  })
  local tmp = path .. ".tmp"
  local f = io.open(tmp, "wb")
  if not f then
    push_error("failed to open " .. tmp)
    return false
  end
  f:write(payload)
  f:close()
  -- Windows rename fails if destination exists; remove first (non-atomic, but
  -- worst case is a brief gap — we are single-writer per PID).
  os.remove(path)
  local ok, err = os.rename(tmp, path)
  if not ok then
    push_error("failed to rename server.json: " .. tostring(err))
    return false
  end
  return true
end

local function delete_server_json(path, own_pid)
  local f = io.open(path, "rb")
  if not f then return end
  local content = f:read("*a")
  f:close()
  local ok, decoded = pcall(json_decode, content or "")
  if not ok or type(decoded) ~= "table" then return end
  if decoded.pid ~= own_pid then return end
  os.remove(path)
end

-- ---------- Bind ----------

local listen, lerr = socket.bind("127.0.0.1", 0)  -- 0 = OS picks port
if not listen then
  push_error("bind failed: " .. tostring(lerr))
  out:push({ kind = "bye" })
  return
end
listen:settimeout(accept_timeout_ms / 1000)
local ip, port = listen:getsockname()

if not write_server_json(server_json_path, port, owner_pid) then
  listen:close()
  out:push({ kind = "bye" })
  return
end

out:push({ kind = "hello", port = port, ip = ip, pid = owner_pid })

-- ---------- Per-connection handling ----------

local MAX_BODY = 65536
local CLIENT_READ_TIMEOUT = 2  -- seconds

local function read_full_request(client)
  client:settimeout(CLIENT_READ_TIMEOUT)
  local buf = ""
  -- Read until end of headers
  while not buf:find("\r\n\r\n", 1, true) do
    local chunk, err, partial = client:receive(4096)
    if chunk then
      buf = buf .. chunk
    elseif partial and #partial > 0 then
      buf = buf .. partial
      if err == "closed" or err == "timeout" then break end
    else
      if err == "closed" or err == "timeout" then break end
      return nil, err
    end
    if #buf > MAX_BODY * 2 then return nil, "oversize" end
  end

  local req = http.parse_request(buf)
  if not req then return nil, "parse failed" end

  -- If Content-Length declared and body incomplete, read the rest
  if req.content_length and #req.body < req.content_length then
    local remaining = req.content_length - #req.body
    if remaining > MAX_BODY then return req, nil end  -- let handle() reject
    local extra, err, partial = client:receive(remaining)
    req.body = req.body .. (extra or partial or "")
    if err and err ~= "closed" and err ~= "timeout" then
      -- fall through; let handle() validate what we have
    end
  end

  return req, nil
end

local function serve_one(client)
  local req, err = read_full_request(client)
  if not req then
    if err ~= "timeout" and err ~= "closed" then
      push_error("read: " .. tostring(err))
    end
    client:close()
    return
  end

  local resp = http.handle(req, auth_token, json_decode, MAX_BODY)
  local raw = http.make_response(resp.status, resp.body)
  client:send(raw)
  client:close()

  if resp.event then
    out:push({
      kind = "event",
      providerId = resp.providerId,
      event = resp.event,
    })
  end
end

-- ---------- Accept loop ----------

while true do
  if ctrl:peek() == "stop" then break end

  local client, aerr = listen:accept()
  if client then
    local ok, perr = pcall(serve_one, client)
    if not ok then push_error("serve: " .. tostring(perr)) end
  elseif aerr and aerr ~= "timeout" then
    push_error("accept: " .. tostring(aerr))
    love.timer.sleep(0.1)
  end
end

listen:close()
delete_server_json(server_json_path, owner_pid)
out:push({ kind = "bye" })
