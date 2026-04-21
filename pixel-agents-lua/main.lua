-- Love2D entry for pixel-agents-lua.
-- S2: single character spawns at door; Space -> find free seat -> walk.

package.path = "./?.lua;./?/init.lua;" .. package.path

local assets = require("src.assets")
local loader = require("src.layout.loader")
local renderer = require("src.systems.renderer")
local world = require("src.world")
local character = require("src.entities.character")
local pathfinder = require("src.systems.pathfinder")

local W

local function log_to_save(msg)
  love.filesystem.append("last-boot.log", msg .. "\n")
end

local function walk_to_free_seat(ch)
  local seat = world.findFreeSeat(W)
  if not seat then
    print("[main] no free seats")
    return
  end

  -- Allow the destination seat tile itself to be the target even though desks
  -- are blocked (seats are walkable — they sit at the desk-front tile).
  local path = pathfinder.findPath({
    size = W.layout.size,
    blocked = W.layout.blocked,
    from = { col = ch.col, row = ch.row },
    to = { col = seat.col, row = seat.row },
  })
  if not path then
    print(string.format("[main] no path from (%d,%d) to seat %s (%d,%d)",
      ch.col, ch.row, seat.id, seat.col, seat.row))
    return
  end

  character.walkTo(ch, path)
  world.assignSeat(W, ch.id, seat.id)
  print(string.format("[main] %s -> seat %s (path len %d)", ch.id, seat.id, #path))
end

function love.load()
  io.stdout:setvbuf("no")
  love.filesystem.write("last-boot.log", "")
  log_to_save("[boot] pixel-agents-lua S2 starting")

  assets.load()
  log_to_save("[boot] assets loaded")

  local layout = loader.load(love.filesystem.getSource() .. "/layouts/mvp_v0.lua")
  W = world.new(layout)

  -- Spawn one character at the door, facing into the office (right).
  local ch = character.new({
    id = "demo",
    col = layout.door.col,
    row = layout.door.row,
    direction = "right",
  })
  world.addCharacter(W, ch)

  log_to_save(string.format("[boot] layout %dx%d seats=%d door=(%d,%d)",
    layout.size.cols, layout.size.rows, #layout.seats,
    layout.door.col, layout.door.row))
  log_to_save("[boot] OK")
  print("[boot] OK  -- press Space to walk to a seat")
end

function love.update(dt)
  -- Cap dt to avoid huge jumps when the window is backgrounded.
  if dt > 0.1 then dt = 0.1 end
  for _, ch in ipairs(W.characters) do
    character.update(ch, dt)
  end
end

function love.draw()
  renderer.draw(W, assets)
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  elseif key == "space" then
    walk_to_free_seat(W.characters[1])
  end
end
