-- Draw the office: floor -> walls -> desks -> chairs -> characters -> bubbles.
-- Caller applies camera transform; renderer only draws world-space.

local character = require("src.entities.character")

local TILE = 16

local BUBBLE_COLORS = {
  waiting    = { 0.2, 0.85, 0.4 },
  permission = { 0.95, 0.75, 0.2 },
}

local M = {}

local function draw_bubble(kind, cx, cy)
  local color = BUBBLE_COLORS[kind]
  if not color then return end
  love.graphics.setColor(color[1], color[2], color[3])
  love.graphics.circle("fill", cx, cy, 4)
  love.graphics.setColor(0, 0, 0)
  love.graphics.circle("line", cx, cy, 4)
  if kind == "waiting" then
    love.graphics.setLineWidth(1)
    love.graphics.line(cx - 2, cy, cx - 1, cy + 1.5, cx + 2, cy - 1.5)
  elseif kind == "permission" then
    love.graphics.circle("fill", cx - 2, cy, 0.6)
    love.graphics.circle("fill", cx, cy, 0.6)
    love.graphics.circle("fill", cx + 2, cy, 0.6)
  end
  love.graphics.setColor(1, 1, 1)
end

function M.draw(world, assets)
  local layout = world.layout

  -- Floor
  for r = 0, layout.size.rows - 1 do
    for c = 0, layout.size.cols - 1 do
      love.graphics.draw(assets.floor, assets.floor_quad, c * TILE, r * TILE)
    end
  end

  -- Walls (extend 16 px above their anchor tile)
  for r = 0, layout.size.rows - 1 do
    for c = 0, layout.size.cols - 1 do
      if layout.walls[c .. "," .. r] then
        love.graphics.draw(assets.wall, assets.wall_quad, c * TILE, r * TILE - TILE)
      end
    end
  end

  -- Desks: 48x32 sprite anchored such that its BOTTOM row aligns with the
  -- bottom of its anchor tile (desk footprint row is the bottom of sprite).
  -- Visually extends 1 tile upward into the space above.
  for _, d in ipairs(layout.desks or {}) do
    love.graphics.draw(
      assets.desk, assets.desk_quad,
      d.col * TILE,
      (d.row + 1) * TILE - 32   -- sprite_height=32 -> top at (row+1)*TILE - 32
    )
  end

  -- Chairs: 16x32 sprite anchored at the seat tile so its BOTTOM aligns with
  -- the seat tile bottom. Drawn before character so the character overlays it.
  for _, ch in ipairs(layout.chairs or {}) do
    love.graphics.draw(
      assets.chair, assets.chair_quad,
      ch.col * TILE,
      (ch.row + 1) * TILE - 32
    )
  end

  -- Characters, z-sorted by floating y
  local chars = {}
  for _, ch in ipairs(world.characters) do chars[#chars + 1] = ch end
  table.sort(chars, function(a, b) return (a.y or a.row) < (b.y or b.row) end)

  for _, ch in ipairs(chars) do
    local info = character.getRenderInfo(ch)
    local quad = assets.char_quad(info.frame, info.dir_row)
    local img = assets.char_image(ch.palette or 0)
    local draw_x = info.x * TILE
    local draw_y = info.y * TILE - TILE
    if info.flip_x then
      love.graphics.draw(img, quad, draw_x + TILE, draw_y, 0, -1, 1)
    else
      love.graphics.draw(img, quad, draw_x, draw_y)
    end
    if info.bubble then
      local bx = info.x * TILE + TILE / 2
      local by = info.y * TILE - TILE - 4
      draw_bubble(info.bubble, bx, by)
    end
  end
end

function M.drawHUD(text_line)
  love.graphics.setColor(0.8, 0.8, 0.9)
  love.graphics.print(text_line or "", 16, love.graphics.getHeight() - 24)
  love.graphics.setColor(1, 1, 1)
end

return M
