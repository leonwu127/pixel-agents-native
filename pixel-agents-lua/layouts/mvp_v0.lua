-- MVP v0 starter office layout.
-- 20 cols x 11 rows. Door on the left edge; 4 DESK_FRONT (3-wide each) with
-- WOODEN_CHAIR_BACK seats directly in front. Border walls on all sides.
--
-- Grid coords (col=0 left, row=0 top):
--
--   col: 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19
-- row 0  W W W W W W W W W W W W W W W W W W W W
-- row 1  W . . . . . . . . . . . . . . . . . . W
-- row 2  W . . . D D D . D D D . D D D . D D D W    <- DESK_FRONT (3-wide) x 4
-- row 3  W . . . . s . . . s . . . s . . . s . W    <- chairs/seats at cols 5, 9, 13, 17
-- row 4  W . . . . . . . . . . . . . . . . . . W
-- row 5  D . . . . . . . . . . . . . . . . . . W    <- door at col 0
-- rows 6-9: walkable floor
-- row 10 W W W W W W W W W W W W W W W W W W W W
--
-- Desk anchor = top-left of its 3x1 footprint. Chair/seat is the single tile
-- directly south-middle of the desk, e.g. DESK at (4,2) -> seat at (5,3).

local COLS, ROWS = 20, 11

local walls = {}
local function add_wall(col, row)
  walls[#walls + 1] = { col = col, row = row }
end

-- Top and bottom border rows
for c = 0, COLS - 1 do
  add_wall(c, 0)
  add_wall(c, ROWS - 1)
end
-- Left and right border columns (skip corners already added, skip door tile)
for r = 1, ROWS - 2 do
  if r ~= 5 then add_wall(0, r) end
  add_wall(COLS - 1, r)
end

-- Four desks, each 3 tiles wide on row 2.
local desks = {
  { col = 4,  row = 2, w = 3, h = 1 },
  { col = 8,  row = 2, w = 3, h = 1 },
  { col = 12, row = 2, w = 3, h = 1 },
  { col = 16, row = 2, w = 3, h = 1 },
}

-- Seats sit on the middle tile directly south of each desk.
local seats = {
  { id = "s1", col = 5,  row = 3 },
  { id = "s2", col = 9,  row = 3 },
  { id = "s3", col = 13, row = 3 },
  { id = "s4", col = 17, row = 3 },
}

return {
  version = 1,
  size = { cols = COLS, rows = ROWS },
  door = { col = 0, row = 5 },
  walls = walls,
  desks = desks,
  seats = seats,
  -- chairs are auto-derived from seats by the loader (one back-facing chair
  -- per seat tile), so we don't repeat them here.
  default_floor = "floor_0",
}
