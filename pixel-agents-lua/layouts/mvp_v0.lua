-- MVP v0 starter office layout.
-- 20 cols × 11 rows. Door on the left edge. 4 vertical DESK_SIDE desks
-- paired with side-facing WOODEN_CHAIR_SIDE chairs so we see characters in
-- profile (arms/hands animating on the keyboard) instead of from behind.
--
-- Grid coords (col=0 left, row=0 top):
--
--   col: 0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16 17 18 19
-- row 0  W  W  W  W  W  W  W  W  W  W  W  W  W  W  W  W  W  W  W  W
-- row 1  W  .  D  .  .  .  D  .  .  .  .  .  .  D  .  .  .  D  .  W
-- row 2  W  .  D  s₁ .  .  D  s₂ .  .  .  .  s₃ D  .  .  s₄ D  .  W
-- row 3  W  .  D  .  .  .  D  .  .  .  .  .  .  D  .  .  .  D  .  W
-- row 4  W  .  D  .  .  .  D  .  .  .  .  .  .  D  .  .  .  D  .  W
-- row 5  D  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  W    <- door at col 0
-- rows 6-9: walkable floor
-- row 10 W  W  W  W  W  W  W  W  W  W  W  W  W  W  W  W  W  W  W  W
--
-- Seat is the single tile immediately east (D1/D2) or west (D3/D4) of each
-- desk. Loader derives seat facing from adjacent desk tiles:
--   s1, s2 → desk to the WEST → facing "left"  (chair orientation: side-left)
--   s3, s4 → desk to the EAST → facing "right" (chair orientation: side)

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

-- Four side-desks (1 wide × 4 tall each). Footprint defaults from orientation
-- in the loader, so we only need to set anchor + orientation.
local desks = {
  { col = 2,  row = 1, orientation = "side" },
  { col = 6,  row = 1, orientation = "side" },
  { col = 13, row = 1, orientation = "side" },
  { col = 17, row = 1, orientation = "side" },
}

-- Seats beside each desk, on the desk's middle row (row 2). Characters will
-- be picked up as facing the desk by the loader's adjacency scan.
local seats = {
  { id = "s1", col = 3,  row = 2 },   -- east of D1 -> faces left
  { id = "s2", col = 7,  row = 2 },   -- east of D2 -> faces left
  { id = "s3", col = 12, row = 2 },   -- west of D3 -> faces right
  { id = "s4", col = 16, row = 2 },   -- west of D4 -> faces right
}

return {
  version = 1,
  size = { cols = COLS, rows = ROWS },
  door = { col = 0, row = 5 },
  walls = walls,
  desks = desks,
  seats = seats,
  -- chairs are auto-derived from seats; orientation follows seat.facing.
  default_floor = "floor_0",
}
