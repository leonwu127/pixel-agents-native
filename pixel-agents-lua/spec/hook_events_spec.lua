package.path = "./?.lua;./?/init.lua;" .. package.path
local helper = require("spec.helper")
local hook_events = require("src.systems.hook_events")

local function ev(name, extra)
  local t = { session_id = "sess-1", hook_event_name = name }
  for k, v in pairs(extra or {}) do t[k] = v end
  return t
end

describe("hook_events.normalize", function()
  it("SessionStart -> spawn", function()
    local e = hook_events.normalize(ev("SessionStart"))
    assert.are.same({ kind = "spawn", sessionId = "sess-1" }, e)
  end)

  it("SessionEnd -> despawn", function()
    local e = hook_events.normalize(ev("SessionEnd"))
    assert.are.same({ kind = "despawn", sessionId = "sess-1" }, e)
  end)

  it("Stop -> turn_end", function()
    local e = hook_events.normalize(ev("Stop"))
    assert.are.same({ kind = "turn_end", sessionId = "sess-1" }, e)
  end)

  it("PreToolUse -> tool_start with tool_name/input/id", function()
    local e = hook_events.normalize(ev("PreToolUse", {
      tool_name   = "Bash",
      tool_input  = { command = "ls" },
      tool_use_id = "toolu_123",
    }))
    assert.are.equal("tool_start", e.kind)
    assert.are.equal("Bash", e.toolName)
    assert.are.equal("toolu_123", e.toolId)
    assert.are.same({ command = "ls" }, e.input)
  end)

  it("PreToolUse without tool_name -> nil", function()
    assert.is_nil(hook_events.normalize(ev("PreToolUse")))
  end)

  it("PostToolUse -> tool_end", function()
    local e = hook_events.normalize(ev("PostToolUse", { tool_use_id = "toolu_1" }))
    assert.are.equal("tool_end", e.kind)
    assert.are.equal("toolu_1", e.toolId)
  end)

  it("PostToolUseFailure -> tool_end (same as PostToolUse)", function()
    local e = hook_events.normalize(ev("PostToolUseFailure", { tool_use_id = "toolu_2" }))
    assert.are.equal("tool_end", e.kind)
    assert.are.equal("toolu_2", e.toolId)
  end)

  it("PermissionRequest -> permission", function()
    local e = hook_events.normalize(ev("PermissionRequest"))
    assert.are.same({ kind = "permission", sessionId = "sess-1" }, e)
  end)

  it("UserPromptSubmit -> prompt_submit", function()
    local e = hook_events.normalize(ev("UserPromptSubmit"))
    assert.are.same({ kind = "prompt_submit", sessionId = "sess-1" }, e)
  end)

  it("Notification -> nil (MVP ignores)", function()
    assert.is_nil(hook_events.normalize(ev("Notification")))
  end)

  it("SubagentStart/Stop -> nil (deferred)", function()
    assert.is_nil(hook_events.normalize(ev("SubagentStart")))
    assert.is_nil(hook_events.normalize(ev("SubagentStop")))
  end)

  it("unknown event name -> nil", function()
    assert.is_nil(hook_events.normalize(ev("FutureEventV99")))
  end)

  it("missing session_id -> nil", function()
    local bad = { hook_event_name = "Stop" }
    assert.is_nil(hook_events.normalize(bad))
  end)

  it("empty session_id -> nil", function()
    local bad = { session_id = "", hook_event_name = "Stop" }
    assert.is_nil(hook_events.normalize(bad))
  end)

  it("missing hook_event_name -> nil", function()
    assert.is_nil(hook_events.normalize({ session_id = "s" }))
  end)

  it("non-table input -> nil", function()
    assert.is_nil(hook_events.normalize("not a table"))
    assert.is_nil(hook_events.normalize(nil))
    assert.is_nil(hook_events.normalize(42))
  end)
end)

-- Integration with world.apply for the two new event kinds
describe("world.apply integration (permission / prompt_submit)", function()
  local world = require("src.world")
  local character = require("src.entities.character")

  local function new_world_with_char()
    local layout = {
      size = { w = 5, h = 5 },
      door = { col = 0, row = 0 },
      seats = { { id = "s1", col = 1, row = 1 } },
      blocked = {},
    }
    local w = world.new(layout)
    local ch = character.new({ id = "sess-1", col = 0, row = 0, palette = 0 })
    world.addCharacter(w, ch)
    return w, ch
  end

  local dummy_provider = { toolStateMap = {}, permissionExemptTools = {} }

  it("permission event sets sticky permission bubble", function()
    local w, ch = new_world_with_char()
    world.apply(w, { kind = "permission", sessionId = "sess-1" }, dummy_provider)
    assert.are.equal("permission", ch.bubble)
    assert.is_nil(ch.bubble_ttl)  -- sticky
  end)

  it("prompt_submit clears any bubble", function()
    local w, ch = new_world_with_char()
    ch.bubble = "waiting"
    ch.bubble_ttl = 1.5
    world.apply(w, { kind = "prompt_submit", sessionId = "sess-1" }, dummy_provider)
    assert.is_nil(ch.bubble)
    assert.is_nil(ch.bubble_ttl)
  end)

  it("tool_end clears permission bubble (existing behavior still holds)", function()
    local w, ch = new_world_with_char()
    world.apply(w, { kind = "tool_start", sessionId = "sess-1",
      toolId = "t1", toolName = "Bash" }, dummy_provider)
    world.apply(w, { kind = "permission", sessionId = "sess-1" }, dummy_provider)
    assert.are.equal("permission", ch.bubble)
    world.apply(w, { kind = "tool_end", sessionId = "sess-1", toolId = "t1" }, dummy_provider)
    assert.is_nil(ch.bubble)
  end)
end)

helper.run()
