-- Love2D entry.
-- S3: watcher thread polls `dev/` for fake JSONL lines. Scene wires
-- watcher -> parser -> provider -> world -> renderer.

package.path = "./?.lua;./?/init.lua;" .. package.path

local assets = require("src.assets")
local loader = require("src.layout.loader")
local provider_mod = require("src.provider")
require("src.providers.claude")       -- self-registers "claude"
local world = require("src.world")
local Office = require("src.scenes.office")

local scene

local function log_to_save(msg)
  love.filesystem.append("last-boot.log", msg .. "\n")
end

function love.load()
  io.stdout:setvbuf("no")
  love.filesystem.write("last-boot.log", "")
  log_to_save("[boot] pixel-agents-lua S3 starting")

  assets.load()
  log_to_save("[boot] assets loaded")

  local game_dir = love.filesystem.getSource()
  local layout = loader.load(game_dir .. "/layouts/mvp_v0.lua")
  local W = world.new(layout)

  -- S3: the "session dir" is our own dev/ folder. S4 will replace this with
  -- the real Claude JSONL path derived from %USERPROFILE% + project hash.
  local fake_dir = game_dir .. "/dev"
  local provider = provider_mod.create("claude", {
    session_dirs_fn = function() return { fake_dir } end,
  })

  scene = Office.new({
    world = W,
    provider = provider,
    dirs = { fake_dir },
    poll_ms = 500,
  })
  scene:start()

  log_to_save(string.format("[boot] watching %s", fake_dir))
  log_to_save("[boot] OK")
  print(string.format("[boot] OK — append a JSONL line to %s to trigger a character", fake_dir))
end

function love.update(dt)
  if scene then scene:update(dt) end
end

function love.draw()
  if scene then scene:draw(assets) end
end

function love.keypressed(key)
  if key == "escape" then love.event.quit() end
end

function love.quit()
  if scene then scene:stop() end
end
