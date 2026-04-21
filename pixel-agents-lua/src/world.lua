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

-- Find characters that were added but have no seat (e.g. spawned while all
-- seats were occupied). Kept in declaration order.
function M.charactersWaitingForSeat(world)
  local result = {}
  local has_seat = {}
  for sid, cid in pairs(world.seat_occupancy) do has_seat[cid] = true end
  for _, ch in ipairs(world.characters) do
    if not has_seat[ch.id] then result[#result + 1] = ch end
  end
  return result
end

-- Pick the least-used palette (0..5) across currently-seated characters.
-- Tie-break by first-least-used (deterministic). Returns integer 0..5.
-- Matches pixel-agents-native's pickDiversePalette algorithm.
function M.pickDiversePalette(world, palette_count)
  palette_count = palette_count or 6
  local counts = {}
  for i = 0, palette_count - 1 do counts[i] = 0 end
  for _, ch in ipairs(world.characters) do
    local p = ch.palette or 0
    if counts[p] then counts[p] = counts[p] + 1 end
  end
  local best_idx = 0
  local best_count = counts[0]
  for i = 1, palette_count - 1 do
    if counts[i] < best_count then
      best_idx = i
      best_count = counts[i]
    end
  end
  return best_idx
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
M.PERMISSION_TIMEOUT = 7.0
M.STALE_TIMEOUT = 60.0

function M.apply(world, event, provider)
  local ch = M.getCharacter(world, event.sessionId)
  if not ch then return false end

  -- Any event resets the character's idle-stale timer.
  ch.idle_time = 0

  if event.kind == "tool_start" then
    ch.active_tool_id = event.toolId
    ch.active_tool_name = event.toolName
    ch.activity = provider.toolStateMap[event.toolName or ""] or nil
    ch.tool_running_time = 0
    ch.bubble = nil
    ch.bubble_ttl = nil
    return true
  end

  if event.kind == "tool_end" then
    if ch.active_tool_id == event.toolId then
      ch.active_tool_id = nil
      ch.active_tool_name = nil
      ch.activity = nil
      ch.tool_running_time = nil
      -- tool_end clears a sticky permission bubble.
      if ch.bubble == "permission" then
        ch.bubble = nil
        ch.bubble_ttl = nil
      end
    end
    return true
  end

  if event.kind == "turn_end" then
    ch.activity = nil
    ch.active_tool_id = nil
    ch.active_tool_name = nil
    ch.tool_running_time = nil
    if ch.bubble == "permission" then
      ch.bubble = nil
    end
    ch.bubble = "waiting"
    ch.bubble_ttl = BUBBLE_WAITING_TTL
    return true
  end

  -- Instant "..." bubble from a PermissionRequest hook. Sticky until the
  -- tool completes (tool_end) or a new turn starts (prompt_submit).
  if event.kind == "permission" then
    ch.bubble = "permission"
    ch.bubble_ttl = nil
    return true
  end

  -- UserPromptSubmit: clears any stale bubble from the previous turn so the
  -- next tool_start / turn_end presents a clean slate.
  if event.kind == "prompt_submit" then
    ch.bubble = nil
    ch.bubble_ttl = nil
    return true
  end

  return false
end

-- Advance timers on every character. Returns a list of session ids that are
-- stale (no event for STALE_TIMEOUT seconds) — caller removes them.
-- `provider` is required for the permission-exempt check on active tools.
function M.tick(world, dt, provider)
  local stale = {}
  for _, ch in ipairs(world.characters) do
    ch.idle_time = (ch.idle_time or 0) + dt

    if ch.tool_running_time then
      ch.tool_running_time = ch.tool_running_time + dt
    end

    if ch.bubble_ttl then
      ch.bubble_ttl = ch.bubble_ttl - dt
      if ch.bubble_ttl <= 0 then
        ch.bubble = nil
        ch.bubble_ttl = nil
      end
    end

    -- Permission timeout: non-exempt tool running for > PERMISSION_TIMEOUT.
    -- In hooks mode (ch.hookDelivered) the explicit PermissionRequest hook
    -- is authoritative, so we skip this polling-driven heuristic to avoid
    -- double-firing.
    if ch.tool_running_time
        and ch.tool_running_time > M.PERMISSION_TIMEOUT
        and ch.active_tool_name
        and ch.bubble ~= "permission"
        and not ch.hookDelivered
        and provider
        and not provider.permissionExemptTools[ch.active_tool_name] then
      ch.bubble = "permission"
      ch.bubble_ttl = nil       -- sticky until tool_end
    end

    if ch.idle_time > M.STALE_TIMEOUT then
      stale[#stale + 1] = ch.id
    end
  end
  return stale
end

return M
