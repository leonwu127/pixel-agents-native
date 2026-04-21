-- Character FSM + animation.
-- Pure Lua (no Love2D) so spec can cover it.
--
-- States: "idle" | "walk"
-- Direction: "down" | "up" | "left" | "right"
-- Sub-tile position kept in (x, y) as floats (tile units); integer tile (col,row)
-- updates as the character crosses tile centers.
--
-- Animation frames (per CLAUDE.md char_0.png layout):
--   frame 0: walk1
--   frame 1: walk2 (also used as idle / stand)
--   frame 2: walk3
--   frame 3: type1, 4: type2, 5: read1, 6: read2 (used in S3+)
-- Direction rows: 0=down, 1=up, 2=right; left = horizontally flipped right.

local WALK_SPEED = 3.0             -- tiles per second
local WALK_FRAME_MS = 180          -- per frame
local WALK_CYCLE = { 0, 1, 2, 1 }  -- walk1 walk2 walk3 walk2 loop
local DIR_ROW = { down = 0, up = 1, right = 2, left = 2 }

local M = {}

function M.new(init)
  return {
    id = init.id,
    col = init.col, row = init.row,
    x = init.col, y = init.row,
    direction = init.direction or "down",
    state = "idle",
    path = nil,
    path_idx = 1,
    anim_time = 0,
    -- anim_cycle_idx indexes into WALK_CYCLE. Idle/stand = walk2 = cycle slot 2.
    anim_cycle_idx = 2,
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

function M.walkTo(ch, path)
  if not path or #path == 0 then return end
  ch.path = path
  ch.path_idx = 1
  -- If the first tile is where we already are, advance past it.
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
  face_toward(ch, ch.path[ch.path_idx])
end

function M.update(ch, dt)
  if ch.state ~= "walk" or not ch.path then
    ch.anim_cycle_idx = 2            -- stand = walk2 slot
    ch.anim_time = 0
    return
  end

  local remaining = dt
  -- Walk along the path, potentially crossing multiple tiles in one update
  -- if dt is large (e.g. the user alt-tabbed and Love2D delivered a big dt).
  while remaining > 0 do
    local target = ch.path[ch.path_idx]
    if not target then
      ch.state = "idle"
      ch.path = nil
      break
    end

    local dx = target.col - ch.x
    local dy = target.row - ch.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist == 0 then
      -- Already at target (possible when path[1] equals spawn tile and wasn't
      -- skipped by walkTo — shouldn't happen in practice, but guard anyway).
      ch.col = target.col
      ch.row = target.row
      ch.path_idx = ch.path_idx + 1
      if ch.path_idx > #ch.path then
        ch.state = "idle"; ch.path = nil; break
      end
      face_toward(ch, ch.path[ch.path_idx])
    elseif WALK_SPEED * remaining >= dist then
      -- Reach this target; consume dist/WALK_SPEED time, continue with the rest.
      local used_time = dist / WALK_SPEED
      remaining = remaining - used_time
      ch.x = target.col; ch.y = target.row
      ch.col = target.col; ch.row = target.row
      ch.path_idx = ch.path_idx + 1
      if ch.path_idx > #ch.path then
        ch.state = "idle"; ch.path = nil; break
      end
      face_toward(ch, ch.path[ch.path_idx])
    else
      -- Partial step toward target; done for this update.
      local step = WALK_SPEED * remaining
      ch.x = ch.x + (dx / dist) * step
      ch.y = ch.y + (dy / dist) * step
      remaining = 0
    end
  end

  -- Advance animation by the full dt (even if we stopped walking mid-update).
  ch.anim_time = ch.anim_time + dt
  while ch.anim_time >= WALK_FRAME_MS / 1000 do
    ch.anim_time = ch.anim_time - (WALK_FRAME_MS / 1000)
    ch.anim_cycle_idx = (ch.anim_cycle_idx % #WALK_CYCLE) + 1
  end
end

-- Returns { frame = <0..6>, dir_row = <0..2>, flip_x = <bool>, x = <float>, y = <float> }
-- suitable for the renderer.
function M.getRenderInfo(ch)
  local frame_idx = WALK_CYCLE[ch.anim_cycle_idx] or 1
  return {
    frame = frame_idx,
    dir_row = DIR_ROW[ch.direction] or 0,
    flip_x = (ch.direction == "left"),
    x = ch.x, y = ch.y,
  }
end

return M
