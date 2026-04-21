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
local config = require("src.config")

local scene

local function log_to_save(msg)
  love.filesystem.append("last-boot.log", msg .. "\n")
end

function love.load()
  io.stdout:setvbuf("no")
  love.filesystem.write("last-boot.log", "")
  log_to_save("[boot] pixel-agents-lua S4 starting")

  assets.load()
  log_to_save("[boot] assets loaded")

  local game_dir = love.filesystem.getSource()
  local workspace = love.filesystem.getWorkingDirectory()
  local conf = config.load(workspace)
  log_to_save(string.format("[boot] workspace=%s", conf.workspacePath))
  log_to_save(string.format("[boot] projectHash=%s", conf.projectHash))
  log_to_save(string.format("[boot] claudeDir=%s", conf.claudeDir))

  local layout = loader.load(game_dir .. "/" .. conf.layoutFile)
  local W = world.new(layout)

  -- Also include the dev/ folder for easy local testing: drop a fake JSONL
  -- there and a character appears without needing to run `claude`.
  local dev_dir = game_dir .. "/dev"
  local watch_dirs = { conf.claudeDir, dev_dir }

  local provider = provider_mod.create("claude", {
    session_dirs_fn = function() return watch_dirs end,
  })

  scene = Office.new({
    world = W,
    provider = provider,
    dirs = watch_dirs,
    poll_ms = conf.pollMs,
  })
  scene:start()

  log_to_save("[boot] OK")
  print(string.format("[boot] OK — watching %d dir(s); workspace=%s",
    #watch_dirs, conf.workspacePath))
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
