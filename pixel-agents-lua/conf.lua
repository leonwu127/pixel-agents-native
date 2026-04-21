function love.conf(t)
  t.identity = "pixel-agents-lua"
  t.window.title = "Pixel Agents"
  t.window.width = 1280
  t.window.height = 720
  t.window.resizable = false
  t.window.vsync = 1
  t.console = true  -- keep the Love2D console window open for print() output
end
