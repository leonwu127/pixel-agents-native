-- Love2D entry for pixel-agents-lua.
-- S1: open window, render a static office, one hardcoded character at seat 1.

package.path = "./?.lua;./?/init.lua;" .. package.path

local assets = require("src.assets")
local loader = require("src.layout.loader")
local renderer = require("src.systems.renderer")

local world

local function log_to_save(msg)
  -- Always write the latest boot diagnostics to the save dir. Useful for
  -- headless boot-smoke tests (the Love2D console is hard to redirect on Windows)
  -- and for debugging what the last run saw.
  love.filesystem.append("last-boot.log", msg .. "\n")
end

function love.load()
  io.stdout:setvbuf("no")
  love.filesystem.write("last-boot.log", "")  -- truncate
  log_to_save("[boot] pixel-agents-lua S1 starting")

  assets.load()
  log_to_save("[boot] assets loaded")

  local layout = loader.load(love.filesystem.getSource() .. "/layouts/mvp_v0.lua")
  world = {
    layout = layout,
    characters = {
      {
        id = "demo",
        col = layout.seats[1].col,
        row = layout.seats[1].row,
        direction = "down",
      },
    },
  }

  local wall_count = 0
  for _ in pairs(layout.walls) do wall_count = wall_count + 1 end
  log_to_save(string.format(
    "[boot] layout %dx%d seats=%d desks=%d walls=%d door=(%d,%d)",
    layout.size.cols, layout.size.rows,
    #layout.seats, #layout.desks, wall_count,
    layout.door.col, layout.door.row))
  log_to_save("[boot] OK  save dir = " .. love.filesystem.getSaveDirectory())
  print("[boot] OK")
end

function love.draw()
  renderer.draw(world, assets)
end

function love.keypressed(key)
  if key == "escape" then love.event.quit() end
end
