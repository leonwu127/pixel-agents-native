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

  -- Desks: two orientations. FRONT is 48x32 (3 wide × 2 tall footprint, runs
  -- horizontally across row d.row–d.row+1); SIDE is 16x64 (1 wide × 4 tall,
  -- runs vertically from d.row to d.row+3). Both are bottom-aligned with
  -- their footprint's last row so the deepest tile defines the z-anchor.
  for _, d in ipairs(layout.desks or {}) do
    local img, quad, h, fp_rows
    if d.orientation == "side" then
      img, quad, h, fp_rows = assets.desk_side, assets.desk_side_quad, 64, 4
    else
      img, quad, h, fp_rows = assets.desk_front, assets.desk_front_quad, 32, 2
    end
    local bottom_row = d.row + fp_rows - 1
    love.graphics.draw(img, quad, d.col * TILE, (bottom_row + 1) * TILE - h)
  end

  -- Chairs: 16x32 for all three orientations. SIDE faces right natively and
  -- is flipped horizontally to face left. Drawn before the character so the
  -- character sprite overlays the seat surface.
  for _, ch in ipairs(layout.chairs or {}) do
    local img, quad
    if ch.orientation == "front" then
      img, quad = assets.chair_front, assets.chair_front_quad
    elseif ch.orientation == "side" or ch.orientation == "side-left" or ch.orientation == "side-right" then
      img, quad = assets.chair_side, assets.chair_side_quad
    else
      img, quad = assets.chair_back, assets.chair_back_quad
    end
    local draw_x = ch.col * TILE
    local draw_y = (ch.row + 1) * TILE - 32
    if ch.orientation == "side-left" then
      -- Mirror horizontally: chair faces left. scaleX = -1 requires offsetting
      -- draw origin by tile width so the sprite still occupies the same tile.
      love.graphics.draw(img, quad, draw_x + TILE, draw_y, 0, -1, 1)
    else
      love.graphics.draw(img, quad, draw_x, draw_y)
    end
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
