-- Load and validate a Lua-format office layout file.
-- See src/layout/types.lua for shape documentation.

local assertf = require("src.assert").assertf

local M = {}

local function tile_key(col, row)
  return tostring(col) .. "," .. tostring(row)
end

M.tile_key = tile_key

local function check_coord(label, t, cols, rows)
  assertf(type(t) == "table", "%s must be a table, got %s", label, type(t))
  assertf(type(t.col) == "number", "%s.col must be a number", label)
  assertf(type(t.row) == "number", "%s.row must be a number", label)
  assertf(t.col >= 0 and t.col < cols, "%s.col out of bounds (0..%d): %d", label, cols - 1, t.col)
  assertf(t.row >= 0 and t.row < rows, "%s.row out of bounds (0..%d): %d", label, rows - 1, t.row)
end

-- Pure validation + transformation: raw-table -> processed-table.
function M.validate(raw)
  assertf(type(raw) == "table", "layout must be a table, got %s", type(raw))

  assertf(type(raw.size) == "table", "layout.size missing")
  local cols = raw.size.cols
  local rows = raw.size.rows
  assertf(type(cols) == "number" and cols > 0, "layout.size.cols must be a positive number")
  assertf(type(rows) == "number" and rows > 0, "layout.size.rows must be a positive number")

  check_coord("layout.door", raw.door, cols, rows)

  assertf(type(raw.seats) == "table" and #raw.seats > 0, "layout.seats must be a non-empty array")

  local seat_ids = {}
  local seats = {}
  for i, s in ipairs(raw.seats) do
    check_coord(string.format("layout.seats[%d]", i), s, cols, rows)
    assertf(type(s.id) == "string" and #s.id > 0, "layout.seats[%d].id must be a non-empty string", i)
    assertf(not seat_ids[s.id], "duplicate seat id: %s", s.id)
    seat_ids[s.id] = true
    seats[i] = { id = s.id, col = s.col, row = s.row }
  end

  local walls = {}
  if raw.walls then
    assertf(type(raw.walls) == "table", "layout.walls must be a table or nil")
    for i, w in ipairs(raw.walls) do
      check_coord(string.format("layout.walls[%d]", i), w, cols, rows)
      walls[tile_key(w.col, w.row)] = true
    end
  end

  local desks = {}
  if raw.desks then
    assertf(type(raw.desks) == "table", "layout.desks must be a table or nil")
    for i, d in ipairs(raw.desks) do
      check_coord(string.format("layout.desks[%d]", i), d, cols, rows)
      local orientation = d.orientation or "front"
      assertf(orientation == "front" or orientation == "side",
        "layout.desks[%d]: orientation must be 'front' or 'side' (got %q)", i, tostring(orientation))
      -- Default footprint depends on orientation so common cases don't have to
      -- repeat the magic numbers: front=3x2, side=1x4.
      local default_w = orientation == "side" and 1 or 3
      local default_h = orientation == "side" and 4 or 2
      local w = d.w or default_w
      local h = d.h or default_h
      assertf(w >= 1 and h >= 1, "layout.desks[%d]: w and h must be >= 1", i)
      assertf(d.col + w - 1 < cols, "layout.desks[%d]: extends past cols (col=%d w=%d)", i, d.col, w)
      assertf(d.row + h - 1 < rows, "layout.desks[%d]: extends past rows (row=%d h=%d)", i, d.row, h)
      desks[i] = { col = d.col, row = d.row, w = w, h = h, orientation = orientation }
    end
  end

  local blocked = {}
  for k, _ in pairs(walls) do blocked[k] = true end
  -- Desk tiles are blocked, with one exception: when a desk's anchor row is
  -- at row 1 (top of playable area), the topmost row of a side-desk sits
  -- outside the visible office — no collision needed there. For simplicity
  -- we still mark every footprint tile as blocked; pathfinder won't care.
  local is_desk = {}
  for _, d in ipairs(desks) do
    for dc = 0, d.w - 1 do
      for dr = 0, d.h - 1 do
        local k = tile_key(d.col + dc, d.row + dr)
        blocked[k] = true
        is_desk[k] = true
      end
    end
  end

  -- Annotate each seat with a facing direction: toward the nearest adjacent
  -- DESK tile (preferred) or fall back to blocked (wall) tile. Prefer
  -- horizontal orientations (L/R) over vertical (U/D) when both are
  -- available so side-desks produce profile-facing characters even if a
  -- wall happens to be behind the chair.
  for _, s in ipairs(seats) do
    local L = tile_key(s.col - 1, s.row)
    local R = tile_key(s.col + 1, s.row)
    local U = tile_key(s.col, s.row - 1)
    local D = tile_key(s.col, s.row + 1)
    if is_desk[L] then s.facing = "left"
    elseif is_desk[R] then s.facing = "right"
    elseif is_desk[U] then s.facing = "up"
    elseif is_desk[D] then s.facing = "down"
    elseif blocked[U] then s.facing = "up"
    elseif blocked[D] then s.facing = "down"
    elseif blocked[R] then s.facing = "right"
    elseif blocked[L] then s.facing = "left"
    else s.facing = "up" end
  end

  -- Chairs are auto-derived from seats. Orientation mirrors the seat's
  -- facing so the chair visually agrees with the character's pose:
  --   facing up    -> chair back   (character has back to viewer — legacy behavior)
  --   facing down  -> chair front  (rare; character faces viewer)
  --   facing right -> chair side   (default side sprite, chair faces right)
  --   facing left  -> chair side-left (mirrored side sprite)
  local chairs = {}
  for _, s in ipairs(seats) do
    local o
    if s.facing == "down" then o = "front"
    elseif s.facing == "right" then o = "side"
    elseif s.facing == "left" then o = "side-left"
    else o = "back" end
    chairs[#chairs + 1] = { col = s.col, row = s.row, orientation = o }
  end

  return {
    size = { cols = cols, rows = rows },
    door = { col = raw.door.col, row = raw.door.row },
    seats = seats,
    walls = walls,
    desks = desks,
    chairs = chairs,
    blocked = blocked,
    default_floor = raw.default_floor or "floor_0",
  }
end

-- Load a layout file from disk and validate it.
function M.load(path)
  local chunk, err = loadfile(path)
  assertf(chunk, "failed to load layout file %s: %s", tostring(path), tostring(err))
  local ok, raw = pcall(chunk)
  assertf(ok, "error executing layout file %s: %s", tostring(path), tostring(raw))
  return M.validate(raw)
end

return M
