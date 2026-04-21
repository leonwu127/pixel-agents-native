-- Load PNG assets borrowed from the sibling `webview-ui/public/assets/` dir.
--
-- Love2D 11.5's `love.filesystem.mount` only accepts paths relative to the save
-- dir, so we can't mount an arbitrary sibling dir. `love.filesystem.mountFullPath`
-- would work but is Love2D 12+. Instead we read the PNG bytes with plain
-- `io.open` (absolute path, no restrictions) and feed them into
-- `love.image.newImageData` to construct an Image.
--
-- Exposes:
--   assets.characters[0..5]   — 6 pre-colored character Images (palette 0..5)
--   assets.char_idle_quad     — 16x32 quad for the standing frame (row 0 = down, frame 1 = walk2)
--   assets.char_quad(palette, frame, dir_row)    — cached sprite Quad lookup
--   assets.floor              — floor_0.png Image (16x16)
--   assets.floor_quad         — 16x16 quad for the full floor tile
--   assets.wall               — wall_0.png Image (64x128, 4x4 grid of 16x32 pieces)
--   assets.wall_quad          — 16x32 quad (top-left piece of the bitmask grid)
--   assets.desk_front         — DESK_FRONT.png  (48x32,  3w x 2h footprint)
--   assets.desk_side          — DESK_SIDE.png   (16x64,  1w x 4h footprint)
--   assets.desk_front_quad    — 48x32 quad
--   assets.desk_side_quad     — 16x64 quad
--   assets.chair_back         — WOODEN_CHAIR_BACK.png  (16x32)
--   assets.chair_side         — WOODEN_CHAIR_SIDE.png  (16x32, faces right; flip for left)
--   assets.chair_front        — WOODEN_CHAIR_FRONT.png (16x32)
--   assets.chair_back_quad / chair_side_quad / chair_front_quad — 16x32 each
--
-- Backwards-compat aliases (pre-S6 renderer used hardcoded front/back pair):
--   assets.desk  = desk_front,   assets.desk_quad  = desk_front_quad
--   assets.chair = chair_back,   assets.chair_quad = chair_back_quad

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

-- Resolve the directory that holds PNG assets. Dev mode reads from the sibling
-- `webview-ui/public/assets` dir in the monorepo; packaged mode (fused .exe)
-- reads from an `assets/` dir beside the executable. We try candidates in
-- order and pick the first one where a sentinel file exists.
local function resolve_assets_dir()
  local candidates
  if love.filesystem.isFused and love.filesystem.isFused() then
    -- Fused: getSource() is the .exe path; parent dir holds the bundled assets.
    local base = love.filesystem.getSourceBaseDirectory()
    candidates = { base .. "/assets" }
  else
    local src = love.filesystem.getSource()  -- pixel-agents-lua/ in dev
    candidates = {
      src .. "/assets",                       -- optional bundled copy
      src .. "/../webview-ui/public/assets",  -- monorepo dev path
    }
  end
  for _, dir in ipairs(candidates) do
    local probe = io.open(dir .. "/floors/floor_0.png", "rb")
    if probe then probe:close(); return dir end
  end
  error(string.format("assets: none of the candidate dirs contain floor_0.png:\n  %s",
    table.concat(candidates, "\n  ")))
end

function M.load()
  love.graphics.setDefaultFilter("nearest", "nearest")

  local assets_dir = resolve_assets_dir()

  -- Load all 6 pre-colored character sheets (char_0..5). They share the same
  -- 112x96 layout, so a single quad set works for any palette.
  M.characters = {}
  for p = 0, 5 do
    M.characters[p] = load_png_abs(assets_dir .. "/characters/char_" .. p .. ".png")
  end
  M.character = M.characters[0]        -- backward-compat alias

  M.floor       = load_png_abs(assets_dir .. "/floors/floor_0.png")
  M.wall        = load_png_abs(assets_dir .. "/walls/wall_0.png")
  M.desk_front  = load_png_abs(assets_dir .. "/furniture/DESK/DESK_FRONT.png")
  M.desk_side   = load_png_abs(assets_dir .. "/furniture/DESK/DESK_SIDE.png")
  M.chair_back  = load_png_abs(assets_dir .. "/furniture/WOODEN_CHAIR/WOODEN_CHAIR_BACK.png")
  M.chair_side  = load_png_abs(assets_dir .. "/furniture/WOODEN_CHAIR/WOODEN_CHAIR_SIDE.png")
  M.chair_front = load_png_abs(assets_dir .. "/furniture/WOODEN_CHAIR/WOODEN_CHAIR_FRONT.png")
  -- Backwards-compat aliases
  M.desk  = M.desk_front
  M.chair = M.chair_back

  -- Character: 7 frames (16 wide each) x 3 direction rows (32 tall each).
  -- Frame order per CLAUDE.md: walk1, walk2, walk3, type1, type2, read1, read2
  -- Rows: 0=down, 1=up, 2=right (left mirrors right at draw-time).
  local cw, ch = M.characters[0]:getDimensions()
  M._char_w, M._char_h = cw, ch
  M.char_idle_quad = love.graphics.newQuad(1 * 16, 0, 16, 32, cw, ch)

  -- All 6 palettes share the same 112x96 layout, so one quad grid serves all.
  M._char_quads = {}
  for dir_row = 0, 2 do
    M._char_quads[dir_row] = {}
    for frame = 0, 6 do
      M._char_quads[dir_row][frame] =
        love.graphics.newQuad(frame * 16, dir_row * 32, 16, 32, cw, ch)
    end
  end

  local function full_quad(img)
    local iw, ih = img:getDimensions()
    return love.graphics.newQuad(0, 0, iw, ih, iw, ih), iw, ih
  end

  M.desk_front_quad  = full_quad(M.desk_front)
  M.desk_side_quad   = full_quad(M.desk_side)
  M.chair_back_quad  = full_quad(M.chair_back)
  M.chair_side_quad  = full_quad(M.chair_side)
  M.chair_front_quad = full_quad(M.chair_front)
  -- Backwards-compat aliases
  M.desk_quad  = M.desk_front_quad
  M.chair_quad = M.chair_back_quad

  local fw, fh = M.floor:getDimensions()
  M.floor_quad = love.graphics.newQuad(0, 0, 16, 16, fw, fh)

  -- walls.png is a 4x4 grid of 16x32 pieces indexed by a 4-bit neighbor bitmask
  -- (N=1 E=2 S=4 W=8). S1 just uses the top-left piece.
  local ww, wh = M.wall:getDimensions()
  M.wall_quad = love.graphics.newQuad(0, 0, 16, 32, ww, wh)

  print(string.format(
    "[assets] loaded: 6 chars + floor + wall + 2 desks + 3 chairs from %s",
    assets_dir))
end

-- Get the Quad for a (frame 0..6, dir_row 0..2) pair. Cached. Same quad
-- applies to every palette since all char sheets share layout.
function M.char_quad(frame, dir_row)
  local row = M._char_quads[dir_row]
  return row and row[frame] or M.char_idle_quad
end

-- Return the Image for a given palette index (0..5, wraps).
function M.char_image(palette)
  palette = palette % 6
  return M.characters[palette] or M.characters[0]
end

return M
