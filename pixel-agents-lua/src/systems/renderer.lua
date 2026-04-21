-- Draw the office: floor -> walls -> desks -> characters.
-- S1 used a static frame; S2+ uses character.getRenderInfo for directional +
-- animated frames and sub-tile (x,y) positions.

local character = require("src.entities.character")

local TILE = 16
local SCALE = 3           -- pixel-perfect integer zoom
local OFFSET_X = 40
local OFFSET_Y = 80       -- leave room for walls that extend 16 px above their anchor tile

local M = {}

function M.draw(world, assets)
  local layout = world.layout

  love.graphics.push()
  love.graphics.translate(OFFSET_X, OFFSET_Y)
  love.graphics.scale(SCALE, SCALE)

  -- Floor
  for r = 0, layout.size.rows - 1 do
    for c = 0, layout.size.cols - 1 do
      love.graphics.draw(assets.floor, assets.floor_quad, c * TILE, r * TILE)
    end
  end

  -- Walls: 16x32 sprite extends one tile above its anchor.
  for r = 0, layout.size.rows - 1 do
    for c = 0, layout.size.cols - 1 do
      if layout.walls[c .. "," .. r] then
        love.graphics.draw(assets.wall, assets.wall_quad, c * TILE, r * TILE - TILE)
      end
    end
  end

  -- Desks (placeholder brown squares — S1/S2 don't use furniture sprites yet).
  love.graphics.setColor(0.55, 0.35, 0.20)
  for _, d in ipairs(layout.desks) do
    love.graphics.rectangle("fill", d.col * TILE + 2, d.row * TILE + 2, TILE - 4, TILE - 4)
  end
  love.graphics.setColor(1, 1, 1)

  -- Characters: z-sort by floating y so southern chars render on top.
  local chars = {}
  for _, ch in ipairs(world.characters) do chars[#chars + 1] = ch end
  table.sort(chars, function(a, b) return (a.y or a.row) < (b.y or b.row) end)

  for _, ch in ipairs(chars) do
    local info = character.getRenderInfo(ch)
    local quad = assets.char_quad(info.frame, info.dir_row)
    local draw_x = info.x * TILE
    local draw_y = info.y * TILE - TILE   -- bottom-align sprite's 32 px to the tile

    if info.flip_x then
      -- Flip by scaling by -1 around the sprite's center.
      love.graphics.draw(assets.character, quad, draw_x + TILE, draw_y, 0, -1, 1)
    else
      love.graphics.draw(assets.character, quad, draw_x, draw_y)
    end
  end

  love.graphics.pop()

  -- HUD
  love.graphics.setColor(0.8, 0.8, 0.9)
  love.graphics.print(
    "Pixel Agents Lua — S2 Walk on demand   |   Space: send to next free seat   |   Esc: quit",
    OFFSET_X, love.graphics.getHeight() - 24)
  love.graphics.setColor(1, 1, 1)
end

return M
