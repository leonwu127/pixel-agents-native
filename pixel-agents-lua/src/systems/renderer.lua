-- Draw the office: floor -> walls -> desks -> characters.
-- S1 uses a fixed zoom and origin; camera comes in later slices.

local TILE = 16
local SCALE = 3        -- pixel-perfect, integer multiple
local OFFSET_X = 40
local OFFSET_Y = 80    -- leave room for walls that extend 16 px above their tile

local M = {}

function M.draw(world, assets)
  local layout = world.layout

  love.graphics.push()
  love.graphics.translate(OFFSET_X, OFFSET_Y)
  love.graphics.scale(SCALE, SCALE)

  -- Floor (every tile)
  for r = 0, layout.size.rows - 1 do
    for c = 0, layout.size.cols - 1 do
      love.graphics.draw(assets.floor, assets.floor_quad, c * TILE, r * TILE)
    end
  end

  -- Walls: wall sprite is 16x32; it extends one tile above its anchor tile.
  for r = 0, layout.size.rows - 1 do
    for c = 0, layout.size.cols - 1 do
      if layout.walls[c .. "," .. r] then
        love.graphics.draw(assets.wall, assets.wall_quad, c * TILE, r * TILE - TILE)
      end
    end
  end

  -- Desks: for S1 we draw a simple brown rectangle per desk tile.
  -- Proper furniture sprites arrive in a later slice.
  love.graphics.setColor(0.55, 0.35, 0.20)
  for _, d in ipairs(layout.desks) do
    love.graphics.rectangle("fill", d.col * TILE + 2, d.row * TILE + 2, TILE - 4, TILE - 4)
  end
  love.graphics.setColor(1, 1, 1)

  -- Characters (z-sort by row for S2+; trivial single char in S1).
  local chars = world.characters
  if chars then
    table.sort(chars, function(a, b) return a.row < b.row end)
    for _, ch in ipairs(chars) do
      love.graphics.draw(assets.character, assets.char_idle_quad,
        ch.col * TILE, ch.row * TILE - TILE)  -- bottom-align sprite to tile
    end
  end

  love.graphics.pop()

  -- HUD: show bottom-line hint
  love.graphics.setColor(0.8, 0.8, 0.9)
  love.graphics.print("Pixel Agents Lua — S1 Hello Office    |    Esc: quit",
    OFFSET_X, love.graphics.getHeight() - 24)
  love.graphics.setColor(1, 1, 1)
end

return M
