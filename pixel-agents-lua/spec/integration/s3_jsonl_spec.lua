-- End-to-end spec for Slice S3: feed raw JSONL lines into parser->provider->world
-- and assert that the world reaches the expected state. No Love2D, no threads.

package.path = "./?.lua;./?/init.lua;" .. package.path
local helper = require("spec.helper")

local loader = require("src.layout.loader")
local world = require("src.world")
local character = require("src.entities.character")
local pathfinder = require("src.systems.pathfinder")
local provider_mod = require("src.provider")
require("src.providers.claude")

-- Minimal "scene-like" helper that spawns a character on first line for a new
-- session id. Mirrors src/scenes/office.lua but without Love2D threading.
local function process_line(W, provider, session_id, line)
  local e = provider.normalize(line)
  if not e then return end
  e.sessionId = session_id
  if not world.getCharacter(W, session_id) then
    local ch = character.new({
      id = session_id,
      col = W.layout.door.col, row = W.layout.door.row,
      direction = "right",
    })
    world.addCharacter(W, ch)
    local seat = world.findFreeSeat(W)
    if seat then
      world.assignSeat(W, session_id, seat.id)
      local path = pathfinder.findPath({
        size = W.layout.size, blocked = W.layout.blocked,
        from = { col = ch.col, row = ch.row },
        to = { col = seat.col, row = seat.row },
      })
      if path then character.walkTo(ch, path) end
    end
  end
  world.apply(W, e, provider)
end

describe("S3 integration — JSONL drives world", function()
  it("first tool_use spawns a character and sets activity=read", function()
    local layout = loader.load("layouts/mvp_v0.lua")
    local W = world.new(layout)
    local p = provider_mod.create("claude")

    local line = [[{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Read","input":{"file_path":"/a"}}]}}]]
    process_line(W, p, "s-123", line)

    local ch = world.getCharacter(W, "s-123")
    assert.is_not_nil(ch)
    assert.are.equal("read", ch.activity)
    assert.are.equal("t1", ch.active_tool_id)
    assert.are.equal("walk", ch.state)   -- walking to seat s1
    assert.are.equal("s-123", W.seat_occupancy["s1"])
  end)

  it("tool_end clears activity; turn_end sets waiting bubble", function()
    local layout = loader.load("layouts/mvp_v0.lua")
    local W = world.new(layout)
    local p = provider_mod.create("claude")

    process_line(W, p, "a", [[{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Write","input":{"file_path":"/x"}}]}}]])
    process_line(W, p, "a", [[{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t1","content":"ok"}]}}]])
    local ch = world.getCharacter(W, "a")
    assert.is_nil(ch.activity)

    process_line(W, p, "a", [[{"type":"system","subtype":"turn_duration","duration_ms":100}]])
    assert.are.equal("waiting", ch.bubble)

    -- Fade after 2s
    world.tick(W, 2.1)
    assert.is_nil(ch.bubble)
  end)

  it("two sessions get two distinct seats", function()
    local layout = loader.load("layouts/mvp_v0.lua")
    local W = world.new(layout)
    local p = provider_mod.create("claude")

    local line_a = [[{"type":"assistant","message":{"content":[{"type":"tool_use","id":"tA","name":"Read","input":{}}]}}]]
    local line_b = [[{"type":"assistant","message":{"content":[{"type":"tool_use","id":"tB","name":"Read","input":{}}]}}]]
    process_line(W, p, "sess-a", line_a)
    process_line(W, p, "sess-b", line_b)

    assert.are.equal("sess-a", W.seat_occupancy["s1"])
    assert.are.equal("sess-b", W.seat_occupancy["s2"])
  end)

  it("text-only assistant line does not create a character", function()
    local layout = loader.load("layouts/mvp_v0.lua")
    local W = world.new(layout)
    local p = provider_mod.create("claude")

    local text_line = [[{"type":"assistant","message":{"content":[{"type":"text","text":"thinking"}]}}]]
    process_line(W, p, "sess-x", text_line)
    assert.is_nil(world.getCharacter(W, "sess-x"))
  end)
end)

helper.run()
