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
      desks[i] = { col = d.col, row = d.row }
    end
  end

  local blocked = {}
  for k, _ in pairs(walls) do blocked[k] = true end
  for _, d in ipairs(desks) do blocked[tile_key(d.col, d.row)] = true end

  return {
    size = { cols = cols, rows = rows },
    door = { col = raw.door.col, row = raw.door.row },
    seats = seats,
    walls = walls,
    desks = desks,
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
