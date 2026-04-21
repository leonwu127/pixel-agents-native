-- Central runtime state.
-- Slice S2: tiny subset (characters, seat occupancy, layout).
-- Later slices extend with event FSM (tool_start/tool_end/turn_end/permission).

local assertf = require("src.assert").assertf

local M = {}

function M.new(layout)
  assertf(layout, "world.new: layout required")
  return {
    layout = layout,
    characters = {},              -- ordered list
    char_index = {},              -- id -> index in characters
    seat_occupancy = {},          -- seat_id -> char_id
  }
end

-- Find the first seat in declared order whose id is not in seat_occupancy.
function M.findFreeSeat(world)
  for _, s in ipairs(world.layout.seats) do
    if not world.seat_occupancy[s.id] then
      return s
    end
  end
  return nil
end

function M.getSeatById(world, seat_id)
  for _, s in ipairs(world.layout.seats) do
    if s.id == seat_id then return s end
  end
  return nil
end

-- Add a new character, optionally at a spawn tile (defaults to layout.door).
function M.addCharacter(world, char)
  assertf(char and char.id, "addCharacter: char.id required")
  assertf(not world.char_index[char.id], "addCharacter: duplicate id %s", char.id)
  world.characters[#world.characters + 1] = char
  world.char_index[char.id] = #world.characters
end

function M.getCharacter(world, id)
  local idx = world.char_index[id]
  return idx and world.characters[idx] or nil
end

-- Assign seat to character (no pathing; caller sets ch.path separately).
function M.assignSeat(world, char_id, seat_id)
  assertf(world.char_index[char_id], "assignSeat: unknown char %s", char_id)
  assertf(M.getSeatById(world, seat_id), "assignSeat: unknown seat %s", seat_id)
  -- Release any previously-held seat for this char.
  for sid, cid in pairs(world.seat_occupancy) do
    if cid == char_id then world.seat_occupancy[sid] = nil end
  end
  world.seat_occupancy[seat_id] = char_id
end

function M.releaseSeat(world, char_id)
  for sid, cid in pairs(world.seat_occupancy) do
    if cid == char_id then world.seat_occupancy[sid] = nil end
  end
end

function M.removeCharacter(world, id)
  local idx = world.char_index[id]
  if not idx then return end
  table.remove(world.characters, idx)
  world.char_index[id] = nil
  -- Reindex subsequent characters.
  for i = idx, #world.characters do
    world.char_index[world.characters[i].id] = i
  end
  M.releaseSeat(world, id)
end

-- ============================================================
-- Per-character event FSM (S3+).
-- Applies a normalized event to one character.
-- event.kind: "tool_start" | "tool_end" | "turn_end"
-- event.sessionId required; must resolve to an existing character.
-- `provider` is the provider instance (for toolStateMap).
-- Returns true if handled, false if character was unknown / event ignored.
-- ============================================================

local BUBBLE_WAITING_TTL = 2.0

function M.apply(world, event, provider)
  local ch = M.getCharacter(world, event.sessionId)
  if not ch then return false end

  if event.kind == "tool_start" then
    ch.active_tool_id = event.toolId
    ch.active_tool_name = event.toolName
    ch.activity = provider.toolStateMap[event.toolName or ""] or nil
    -- New activity clears any waiting bubble.
    ch.bubble = nil
    ch.bubble_ttl = nil
    return true
  end

  if event.kind == "tool_end" then
    if ch.active_tool_id == event.toolId then
      ch.active_tool_id = nil
      ch.active_tool_name = nil
      ch.activity = nil
    end
    return true
  end

  if event.kind == "turn_end" then
    ch.activity = nil
    ch.active_tool_id = nil
    ch.active_tool_name = nil
    ch.bubble = "waiting"
    ch.bubble_ttl = BUBBLE_WAITING_TTL
    return true
  end

  return false
end

-- Time-based effects: fade bubbles.
function M.tick(world, dt)
  for _, ch in ipairs(world.characters) do
    if ch.bubble_ttl then
      ch.bubble_ttl = ch.bubble_ttl - dt
      if ch.bubble_ttl <= 0 then
        ch.bubble = nil
        ch.bubble_ttl = nil
      end
    end
  end
end

return M
