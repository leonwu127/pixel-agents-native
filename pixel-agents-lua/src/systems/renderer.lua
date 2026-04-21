-- Draw the office: floor -> walls -> desks -> characters -> bubbles.

local character = require("src.entities.character")

local TILE = 16
local SCALE = 3
local OFFSET_X = 40
local OFFSET_Y = 80

local BUBBLE_COLORS = {
  waiting    = { 0.2, 0.85, 0.4 },   -- green
  permission = { 0.95, 0.75, 0.2 },  -- amber
}

local M = {}

local function draw_bubble(kind, cx, cy)
  local color = BUBBLE_COLORS[kind]
  if not color then return end
  -- Bubble body (8x8 in world-pixel units, anchored above character)
  love.graphics.setColor(color[1], color[2], color[3])
  love.graphics.circle("fill", cx, cy, 4)
  love.graphics.setColor(0, 0, 0)
  love.graphics.circle("line", cx, cy, 4)
  -- Glyph
  love.graphics.setColor(0, 0, 0)
  if kind == "waiting" then
    -- small check mark
    love.graphics.setLineWidth(1)
    love.graphics.line(cx - 2, cy, cx - 1, cy + 1.5, cx + 2, cy - 1.5)
  elseif kind == "permission" then
    -- three dots
    love.graphics.circle("fill", cx - 2, cy, 0.6)
    love.graphics.circle("fill", cx, cy, 0.6)
    love.graphics.circle("fill", cx + 2, cy, 0.6)
  end
  love.graphics.setColor(1, 1, 1)
end

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

  -- Walls
  for r = 0, layout.size.rows - 1 do
    for c = 0, layout.size.cols - 1 do
      if layout.walls[c .. "," .. r] then
        love.graphics.draw(assets.wall, assets.wall_quad, c * TILE, r * TILE - TILE)
      end
    end
  end

  -- Desks (placeholder)
  love.graphics.setColor(0.55, 0.35, 0.20)
  for _, d in ipairs(layout.desks) do
    love.graphics.rectangle("fill", d.col * TILE + 2, d.row * TILE + 2, TILE - 4, TILE - 4)
  end
  love.graphics.setColor(1, 1, 1)

  -- Characters, z-sorted by floating y
  local chars = {}
  for _, ch in ipairs(world.characters) do chars[#chars + 1] = ch end
  table.sort(chars, function(a, b) return (a.y or a.row) < (b.y or b.row) end)

  for _, ch in ipairs(chars) do
    local info = character.getRenderInfo(ch)
    local quad = assets.char_quad(info.frame, info.dir_row)
    local draw_x = info.x * TILE
    local draw_y = info.y * TILE - TILE
    if info.flip_x then
      love.graphics.draw(assets.character, quad, draw_x + TILE, draw_y, 0, -1, 1)
    else
      love.graphics.draw(assets.character, quad, draw_x, draw_y)
    end
    if info.bubble then
      -- bubble floats ~8 px above the sprite top
      local bx = info.x * TILE + TILE / 2
      local by = info.y * TILE - TILE - 4
      draw_bubble(info.bubble, bx, by)
    end
  end

  love.graphics.pop()

  -- HUD
  love.graphics.setColor(0.8, 0.8, 0.9)
  love.graphics.print(
    "Pixel Agents Lua — S3 Fake JSONL drives it   |   Append to dev/fake-session.jsonl   |   Esc: quit",
    OFFSET_X, love.graphics.getHeight() - 24)
  love.graphics.setColor(1, 1, 1)
end

return M
