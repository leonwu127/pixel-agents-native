-- MVP v0 starter office layout.
-- 20 cols x 11 rows. Door at the left edge, a row of 4 desks with seats below.
--
-- Grid coords (col=0 left, row=0 top):
--
--   col: 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19
-- row 0  W W W W W W W W W W W W W W W W W W W W
-- row 1  W . . . . . . . . . . . . . . . . . . W
-- row 2  W . . . . D . . D . .  .  D  .  .  D  .  .  .  W
-- row 3  W . . . . s . . s . .  .  s  .  .  s  .  .  .  W   <- seats 1..4
-- row 4  W . . . . . . . . . .  .  .  .  .  .  .  .  .  W
-- row 5  D . . . . . . . . . .  .  .  .  .  .  .  .  .  W   <- door at col 0
-- row 6  W . . . . . . . . . .  .  .  .  .  .  .  .  .  W
-- row 7  W . . . . . . . . . .  .  .  .  .  .  .  .  .  W
-- row 8  W . . . . . . . . . .  .  .  .  .  .  .  .  .  W
-- row 9  W . . . . . . . . . .  .  .  .  .  .  .  .  .  W
-- row 10 W W W W W W W W W W W W W W W W W W W W
--
-- W = wall, D = desk, s = seat, . = walkable floor.
-- The door tile itself is NOT a wall (characters enter through it).

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
  if r ~= 5 then add_wall(0, r) end  -- col 0 open at row 5 = door
  add_wall(COLS - 1, r)
end

return {
  version = 1,
  size = { cols = COLS, rows = ROWS },
  door = { col = 0, row = 5 },
  walls = walls,
  desks = {
    { col = 5,  row = 2 },
    { col = 8,  row = 2 },
    { col = 12, row = 2 },
    { col = 15, row = 2 },
  },
  seats = {
    { id = "s1", col = 5,  row = 3 },
    { id = "s2", col = 8,  row = 3 },
    { id = "s3", col = 12, row = 3 },
    { id = "s4", col = 15, row = 3 },
  },
  default_floor = "floor_0",
}
