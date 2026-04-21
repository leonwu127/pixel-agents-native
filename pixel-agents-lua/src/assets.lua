-- Load PNG assets borrowed from the sibling `webview-ui/public/assets/` dir.
--
-- Love2D 11.5's `love.filesystem.mount` only accepts paths relative to the save
-- dir, so we can't mount an arbitrary sibling dir. `love.filesystem.mountFullPath`
-- would work but is Love2D 12+. Instead we read the PNG bytes with plain
-- `io.open` (absolute path, no restrictions) and feed them into
-- `love.image.newImageData` to construct an Image.
--
-- Exposes:
--   assets.character          — char_0.png Image (112x96, 7 frames x 3 directions)
--   assets.char_idle_quad     — 16x32 quad for the standing frame (row 0 = down, frame 1 = walk2)
--   assets.floor              — floor_0.png Image (16x16)
--   assets.floor_quad         — 16x16 quad for the full floor tile
--   assets.wall               — wall_0.png Image (64x128, 4x4 grid of 16x32 pieces)
--   assets.wall_quad          — 16x32 quad (top-left piece of the bitmask grid)

local M = {}

local function load_png_abs(abs_path)
  local f, open_err = io.open(abs_path, "rb")
  if not f then
    error(string.format("assets: failed to open %q: %s", abs_path, tostring(open_err)))
  end
  local bytes = f:read("*all")
  f:close()

  -- newFileData(contents, name) wraps raw bytes; name is used for error messages.
  local filedata = love.filesystem.newFileData(bytes, abs_path)
  local image_data = love.image.newImageData(filedata)
  local img = love.graphics.newImage(image_data)
  img:setFilter("nearest", "nearest")
  return img
end

function M.load()
  love.graphics.setDefaultFilter("nearest", "nearest")

  local game_dir = love.filesystem.getSource()       -- absolute path to pixel-agents-lua
  local assets_dir = game_dir .. "/../webview-ui/public/assets"

  M.character = load_png_abs(assets_dir .. "/characters/char_0.png")
  M.floor     = load_png_abs(assets_dir .. "/floors/floor_0.png")
  M.wall      = load_png_abs(assets_dir .. "/walls/wall_0.png")

  -- Character: 7 frames (16 wide each) x 3 direction rows (32 tall each).
  -- Frame order per CLAUDE.md: walk1, walk2, walk3, type1, type2, read1, read2
  -- "Idle" uses walk2 (index 1, 0-based).
  local cw, ch = M.character:getDimensions()
  M.char_idle_quad = love.graphics.newQuad(1 * 16, 0, 16, 32, cw, ch)

  local fw, fh = M.floor:getDimensions()
  M.floor_quad = love.graphics.newQuad(0, 0, 16, 16, fw, fh)

  -- walls.png is a 4x4 grid of 16x32 pieces indexed by a 4-bit neighbor bitmask
  -- (N=1 E=2 S=4 W=8). S1 just uses the top-left piece.
  local ww, wh = M.wall:getDimensions()
  M.wall_quad = love.graphics.newQuad(0, 0, 16, 32, ww, wh)

  print(string.format("[assets] loaded 3 PNGs from %s", assets_dir))
end

return M
