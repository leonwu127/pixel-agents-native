-- Character FSM + animation.
-- Pure Lua (no Love2D) so spec can cover it.
--
-- State:
--   state       : "idle" | "walk"              — base locomotion
--   activity    : nil | "read" | "type"        — overlays on idle (driven by tool_start/tool_end)
--   bubble      : nil | "waiting" | "permission"
--   bubble_ttl  : seconds left (nil = no timer)
--
-- Animation frame map (per CLAUDE.md char_0.png layout):
--   0: walk1, 1: walk2 (stand), 2: walk3,
--   3: type1, 4: type2,
--   5: read1, 6: read2
-- Direction rows: 0=down, 1=up, 2=right; left mirrors right at draw-time.

local WALK_SPEED    = 3.0           -- tiles per second
local FRAME_MS      = 180           -- per animation frame
local WALK_CYCLE    = { 0, 1, 2, 1 }
local TYPE_CYCLE    = { 3, 4 }
local READ_CYCLE    = { 5, 6 }
local DIR_ROW       = { down = 0, up = 1, right = 2, left = 2 }

local M = {}

function M.new(init)
  return {
    id = init.id,
    col = init.col, row = init.row,
    x = init.col, y = init.row,
    direction = init.direction or "down",
    state = "idle",
    activity = nil,                  -- "read" | "type" | nil
    active_tool_id = nil,
    active_tool_name = nil,
    bubble = nil,                    -- "waiting" | "permission" | nil
    bubble_ttl = nil,
    path = nil,
    path_idx = 1,
    anim_time = 0,
    palette = init.palette or 0,     -- 0..5; selects which char_N.png sheet
  }
end

local function face_toward(ch, target)
  local dc = target.col - ch.col
  local dr = target.row - ch.row
  if math.abs(dc) >= math.abs(dr) then
    ch.direction = dc >= 0 and "right" or "left"
  else
    ch.direction = dr >= 0 and "down" or "up"
  end
end

M.face_toward = face_toward

local function pick_cycle(ch)
  if ch.state == "walk" then return WALK_CYCLE end
  if ch.activity == "read" then return READ_CYCLE end
  if ch.activity == "type" then return TYPE_CYCLE end
  return nil                         -- idle stand, single frame
end

function M.walkTo(ch, path)
  if not path or #path == 0 then return end
  ch.path = path
  ch.path_idx = 1
  while ch.path_idx <= #ch.path
    and ch.path[ch.path_idx].col == ch.col
    and ch.path[ch.path_idx].row == ch.row do
    ch.path_idx = ch.path_idx + 1
  end
  if ch.path_idx > #ch.path then
    ch.state = "idle"
    ch.path = nil
    return
  end
  ch.state = "walk"
  ch.anim_time = 0
  face_toward(ch, ch.path[ch.path_idx])
end

function M.update(ch, dt)
  -- Movement
  if ch.state == "walk" and ch.path then
    local remaining = dt
    while remaining > 0 do
      local target = ch.path[ch.path_idx]
      if not target then
        ch.state = "idle"; ch.path = nil; break
      end
      local dx = target.col - ch.x
      local dy = target.row - ch.y
      local dist = math.sqrt(dx * dx + dy * dy)

      if dist == 0 then
        ch.col = target.col; ch.row = target.row
        ch.path_idx = ch.path_idx + 1
        if ch.path_idx > #ch.path then
          ch.state = "idle"; ch.path = nil; break
        end
        face_toward(ch, ch.path[ch.path_idx])
      elseif WALK_SPEED * remaining >= dist then
        local used = dist / WALK_SPEED
        remaining = remaining - used
        ch.x = target.col; ch.y = target.row
        ch.col = target.col; ch.row = target.row
        ch.path_idx = ch.path_idx + 1
        if ch.path_idx > #ch.path then
          ch.state = "idle"; ch.path = nil; break
        end
        face_toward(ch, ch.path[ch.path_idx])
      else
        local step = WALK_SPEED * remaining
        ch.x = ch.x + (dx / dist) * step
        ch.y = ch.y + (dy / dist) * step
        remaining = 0
      end
    end
  end

  -- Animation time: accumulate for animated cycles, reset for static idle.
  if pick_cycle(ch) then
    ch.anim_time = ch.anim_time + dt
  else
    ch.anim_time = 0
  end
end

function M.getRenderInfo(ch)
  local cycle = pick_cycle(ch)
  local frame
  if cycle then
    local step = math.floor(ch.anim_time / (FRAME_MS / 1000))
    frame = cycle[(step % #cycle) + 1]
  else
    frame = 1                        -- walk2 = stand
  end
  return {
    frame = frame,
    dir_row = DIR_ROW[ch.direction] or 0,
    flip_x = (ch.direction == "left"),
    x = ch.x,
    y = ch.y,
    bubble = ch.bubble,
  }
end

return M
