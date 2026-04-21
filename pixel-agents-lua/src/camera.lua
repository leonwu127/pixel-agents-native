-- 2D camera with integer-multiple zoom and middle-mouse drag pan.
-- `apply(cam)` pushes a graphics transform; `pop(cam)` restores it.
-- Zoom snaps to integer values to preserve pixel-perfect rendering.

local M = {}

local MIN_ZOOM     = 1
local MAX_ZOOM     = 6
local DEFAULT_ZOOM = 3
local DEFAULT_X    = 40
local DEFAULT_Y    = 80

function M.new(opts)
  opts = opts or {}
  return {
    x = opts.x or DEFAULT_X,
    y = opts.y or DEFAULT_Y,
    zoom = opts.zoom or DEFAULT_ZOOM,
    drag = nil,       -- { start_mx, start_my, start_cx, start_cy } while middle-button held
  }
end

function M.apply(cam)
  love.graphics.push()
  love.graphics.translate(cam.x, cam.y)
  love.graphics.scale(cam.zoom, cam.zoom)
end

function M.pop(_)
  love.graphics.pop()
end

function M.mousepressed(cam, mx, my, button)
  if button == 3 then    -- middle mouse
    cam.drag = { start_mx = mx, start_my = my, start_cx = cam.x, start_cy = cam.y }
  end
end

function M.mousereleased(cam, _, _, button)
  if button == 3 then
    cam.drag = nil
  end
end

function M.mousemoved(cam, mx, my)
  if cam.drag then
    cam.x = cam.drag.start_cx + (mx - cam.drag.start_mx)
    cam.y = cam.drag.start_cy + (my - cam.drag.start_my)
  end
end

function M.wheelmoved(cam, _dx, dy)
  if dy > 0 then
    cam.zoom = math.min(MAX_ZOOM, cam.zoom + 1)
  elseif dy < 0 then
    cam.zoom = math.max(MIN_ZOOM, cam.zoom - 1)
  end
end

return M
