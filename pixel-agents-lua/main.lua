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
local camera_mod = require("src.camera")

local hook_server_mod = require("src.systems.hook_server")
local installer = require("src.systems.installer")
local http_mod = require("src.systems.http")
local json_decode = require("src.vendor.json").decode

local scene
local cam
local hook_server_inst
local hooks_installed = false  -- true only if we successfully wrote settings.json on boot

-- Best-effort PID lookup via LuaJIT FFI (Love2D ships LuaJIT). Falls back to 0
-- if FFI is unavailable, which just means server.json ownership can't be
-- verified by PID — harmless in single-instance usage.
local function get_own_pid()
  local ok, ffi = pcall(require, "ffi")
  if not ok then return 0 end
  pcall(ffi.cdef, "unsigned long GetCurrentProcessId(void);")
  local ok2, pid = pcall(function() return tonumber(ffi.C.GetCurrentProcessId()) end)
  if ok2 then return pid or 0 end
  return 0
end

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

  cam = camera_mod.new()

  if conf.hooksEnabled then
    local pid = get_own_pid()
    local home = config.user_home()
    hook_server_inst = hook_server_mod.new({
      user_home = home,
      owner_pid = pid,
    })
    local ok, err = pcall(function() hook_server_inst:start() end)
    if not ok then
      print("[boot] hook_server start failed: " .. tostring(err))
      log_to_save("[boot] hook_server start failed: " .. tostring(err))
      hook_server_inst = nil
    else
      log_to_save(string.format("[boot] hook server started (pid=%d)", pid))

      -- Copy PowerShell hook script + install settings.json entries.
      local json = { encode = http_mod.json_encode, decode = json_decode }
      local io_ops = installer.make_io_ops()
      local copied, dst, cerr = installer.install_hook_script(io_ops, game_dir, home)
      if not copied then
        log_to_save("[boot] hook script copy failed: " .. tostring(cerr))
        print("[boot] hook script copy failed: " .. tostring(cerr))
      else
        log_to_save("[boot] hook script copied to " .. dst)
        local installed, ierr = installer.install(io_ops, json,
          installer.claude_settings_path(home), dst)
        if installed then
          hooks_installed = true
          log_to_save("[boot] hooks installed in ~/.claude/settings.json")
          print("[boot] hooks installed in ~/.claude/settings.json")
        else
          log_to_save("[boot] hooks install failed: " .. tostring(ierr))
          print("[boot] hooks install failed: " .. tostring(ierr))
        end
      end
    end
  else
    log_to_save("[boot] hooks disabled (set hooksEnabled=true in config.lua to enable)")
  end

  log_to_save("[boot] OK")
  print(string.format("[boot] OK — watching %d dir(s); workspace=%s",
    #watch_dirs, conf.workspacePath))
end

function love.update(dt)
  local hook_msgs = nil
  if hook_server_inst then
    hook_msgs = hook_server_inst:drain()
    for _, m in ipairs(hook_msgs) do
      if m.kind == "event" then
        print(string.format("[hook] %s %s session=%s",
          m.providerId, m.event.hook_event_name or "?", m.event.session_id or "?"))
      end
    end
    hook_server_inst:check_thread_error()
  end
  if scene then scene:update(dt, hook_msgs) end
end

function love.draw()
  if scene then scene:draw(assets, camera_mod, cam) end
end

function love.keypressed(key)
  if key == "escape" then love.event.quit() end
end

function love.mousepressed(x, y, button)
  if cam then camera_mod.mousepressed(cam, x, y, button) end
end

function love.mousereleased(x, y, button)
  if cam then camera_mod.mousereleased(cam, x, y, button) end
end

function love.mousemoved(x, y)
  if cam then camera_mod.mousemoved(cam, x, y) end
end

function love.wheelmoved(dx, dy)
  if cam then camera_mod.wheelmoved(cam, dx, dy) end
end

function love.quit()
  if hooks_installed then
    local json = { encode = http_mod.json_encode, decode = json_decode }
    local io_ops = installer.make_io_ops()
    local home = config.user_home()
    local ok, err = installer.uninstall(io_ops, json, installer.claude_settings_path(home))
    if ok then
      print("[quit] hooks removed from ~/.claude/settings.json")
    else
      print("[quit] hooks uninstall failed: " .. tostring(err))
    end
  end
  if hook_server_inst then hook_server_inst:stop() end
  if scene then scene:stop() end
end
