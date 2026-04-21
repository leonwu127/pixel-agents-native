-- Scene that wires everything together: spawns the watcher thread, drains its
-- channel each frame, dispatches provider-normalized events to the world, and
-- invokes character updates + renderer.

local world = require("src.world")
local character = require("src.entities.character")
local pathfinder = require("src.systems.pathfinder")
local renderer = require("src.systems.renderer")

local M = {}
M.__index = M

local EVENTS_CHANNEL = "agent_events"
local CONTROL_CHANNEL = "watcher_control"

function M.new(opts)
  local scene = setmetatable({
    world = opts.world,
    provider = opts.provider,
    dirs = opts.dirs or {},
    poll_ms = opts.poll_ms or 500,
    thread = nil,
  }, M)
  return scene
end

function M:start()
  -- Join dirs with | so watcher_thread can re-split (thread:start only passes scalars).
  local dirs_csv = table.concat(self.dirs, "|")
  self.thread = love.thread.newThread("src/systems/watcher_thread.lua")
  self.thread:start(dirs_csv, self.provider.sessionFilePattern, self.poll_ms)
  print(string.format("[scene] watcher thread started: dirs=[%s] pattern=%q poll=%dms",
    table.concat(self.dirs, ", "), self.provider.sessionFilePattern, self.poll_ms))
end

function M:stop()
  if self.thread then
    love.thread.getChannel(CONTROL_CHANNEL):push("stop")
    self.thread:wait()
    self.thread = nil
  end
end

function M:_spawn_character(session_id)
  local w = self.world
  if world.getCharacter(w, session_id) then return end

  local ch = character.new({
    id = session_id,
    col = w.layout.door.col,
    row = w.layout.door.row,
    direction = "right",
  })
  world.addCharacter(w, ch)

  local seat = world.findFreeSeat(w)
  if seat then
    world.assignSeat(w, session_id, seat.id)
    local path = pathfinder.findPath({
      size = w.layout.size,
      blocked = w.layout.blocked,
      from = { col = ch.col, row = ch.row },
      to = { col = seat.col, row = seat.row },
    })
    if path then character.walkTo(ch, path) end
    print(string.format("[scene] spawned %s -> seat %s", session_id, seat.id))
  else
    print(string.format("[scene] spawned %s -> idle at door (no free seat)", session_id))
  end
end

function M:_on_line_msg(msg)
  local sid = msg.session_id
  local event = self.provider.normalize(msg.line)
  if not event then return end  -- irrelevant line
  event.sessionId = sid

  if not world.getCharacter(self.world, sid) then
    self:_spawn_character(sid)
  end

  world.apply(self.world, event, self.provider)
end

function M:_drain_events()
  local ch = love.thread.getChannel(EVENTS_CHANNEL)
  while true do
    local msg = ch:pop()
    if not msg then break end
    if msg.kind == "hello" then
      print(string.format("[scene] watcher ready, watching %d dir(s)", #msg.dirs))
    elseif msg.kind == "line" then
      self:_on_line_msg(msg)
    elseif msg.kind == "bye" then
      print("[scene] watcher thread exited")
    end
  end
end

function M:update(dt)
  self:_drain_events()
  if dt > 0.1 then dt = 0.1 end
  for _, ch in ipairs(self.world.characters) do
    character.update(ch, dt)
  end
  world.tick(self.world, dt)

  -- Surface watcher thread errors
  if self.thread then
    local err = self.thread:getError()
    if err then
      print("[scene] watcher thread error: " .. tostring(err))
      self.thread = nil
    end
  end
end

function M:draw(assets)
  renderer.draw(self.world, assets)
end

return M
