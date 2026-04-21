package.path = "./?.lua;./?/init.lua;" .. package.path
local helper = require("spec.helper")
local world = require("src.world")
local loader = require("src.layout.loader")

local function small_layout()
  return loader.validate({
    size = { cols = 10, rows = 10 },
    door = { col = 0, row = 5 },
    seats = {
      { id = "s1", col = 2, row = 3 },
      { id = "s2", col = 4, row = 3 },
      { id = "s3", col = 6, row = 3 },
    },
  })
end

local function mk_char(id, col, row)
  return { id = id, col = col or 0, row = row or 5, state = "idle" }
end

describe("world.new", function()
  it("creates an empty world with the layout", function()
    local w = world.new(small_layout())
    assert.are.equal(10, w.layout.size.cols)
    assert.are.equal(0, #w.characters)
    assert.are.same({}, w.seat_occupancy)
  end)

  it("errors on nil layout", function()
    assert.has_error(function() world.new(nil) end, "layout required")
  end)
end)

describe("world.findFreeSeat", function()
  it("returns the first seat when empty", function()
    local w = world.new(small_layout())
    local s = world.findFreeSeat(w)
    assert.are.equal("s1", s.id)
  end)

  it("skips occupied seats in declaration order", function()
    local w = world.new(small_layout())
    world.addCharacter(w, mk_char("a"))
    world.assignSeat(w, "a", "s1")
    assert.are.equal("s2", world.findFreeSeat(w).id)

    world.addCharacter(w, mk_char("b"))
    world.assignSeat(w, "b", "s2")
    assert.are.equal("s3", world.findFreeSeat(w).id)
  end)

  it("returns nil when all seats taken", function()
    local w = world.new(small_layout())
    for _, id in ipairs({ "a", "b", "c" }) do
      world.addCharacter(w, mk_char(id))
      world.assignSeat(w, id, world.findFreeSeat(w).id)
    end
    assert.is_nil(world.findFreeSeat(w))
  end)
end)

describe("world.addCharacter", function()
  it("registers by id", function()
    local w = world.new(small_layout())
    world.addCharacter(w, mk_char("a"))
    assert.are.equal("a", world.getCharacter(w, "a").id)
  end)

  it("errors on duplicate id", function()
    local w = world.new(small_layout())
    world.addCharacter(w, mk_char("a"))
    assert.has_error(function() world.addCharacter(w, mk_char("a")) end, "duplicate id a")
  end)

  it("errors on missing id", function()
    local w = world.new(small_layout())
    assert.has_error(function() world.addCharacter(w, {}) end, "char.id required")
  end)
end)

describe("world.assignSeat + releaseSeat", function()
  it("assigns seat and re-assignment releases prior seat", function()
    local w = world.new(small_layout())
    world.addCharacter(w, mk_char("a"))
    world.assignSeat(w, "a", "s1")
    assert.are.equal("a", w.seat_occupancy["s1"])

    world.assignSeat(w, "a", "s2")
    assert.is_nil(w.seat_occupancy["s1"])  -- released
    assert.are.equal("a", w.seat_occupancy["s2"])
  end)

  it("releaseSeat clears the character's seat", function()
    local w = world.new(small_layout())
    world.addCharacter(w, mk_char("a"))
    world.assignSeat(w, "a", "s1")
    world.releaseSeat(w, "a")
    assert.is_nil(w.seat_occupancy["s1"])
  end)

  it("errors assigning unknown character", function()
    local w = world.new(small_layout())
    assert.has_error(function() world.assignSeat(w, "ghost", "s1") end, "unknown char ghost")
  end)

  it("errors assigning unknown seat", function()
    local w = world.new(small_layout())
    world.addCharacter(w, mk_char("a"))
    assert.has_error(function() world.assignSeat(w, "a", "sX") end, "unknown seat sX")
  end)
end)

describe("world.apply — event FSM", function()
  local function fake_provider()
    return { toolStateMap = { Read = "read", Write = "type", Bash = "type" } }
  end

  it("tool_start sets ch.activity via provider.toolStateMap", function()
    local w = world.new(small_layout())
    world.addCharacter(w, mk_char("a"))
    local handled = world.apply(w, { kind = "tool_start", sessionId = "a", toolName = "Read", toolId = "t1" }, fake_provider())
    assert.is_true(handled)
    local ch = world.getCharacter(w, "a")
    assert.are.equal("read", ch.activity)
    assert.are.equal("t1", ch.active_tool_id)
    assert.are.equal("Read", ch.active_tool_name)
  end)

  it("tool_end clears activity when toolId matches", function()
    local w = world.new(small_layout())
    world.addCharacter(w, mk_char("a"))
    world.apply(w, { kind = "tool_start", sessionId = "a", toolName = "Write", toolId = "tW" }, fake_provider())
    world.apply(w, { kind = "tool_end", sessionId = "a", toolId = "tW" }, fake_provider())
    local ch = world.getCharacter(w, "a")
    assert.is_nil(ch.activity)
    assert.is_nil(ch.active_tool_id)
  end)

  it("tool_end ignores non-matching toolId", function()
    local w = world.new(small_layout())
    world.addCharacter(w, mk_char("a"))
    world.apply(w, { kind = "tool_start", sessionId = "a", toolName = "Write", toolId = "tW" }, fake_provider())
    world.apply(w, { kind = "tool_end", sessionId = "a", toolId = "other" }, fake_provider())
    assert.are.equal("tW", world.getCharacter(w, "a").active_tool_id)
  end)

  it("turn_end sets waiting bubble with 2s ttl", function()
    local w = world.new(small_layout())
    world.addCharacter(w, mk_char("a"))
    world.apply(w, { kind = "tool_start", sessionId = "a", toolName = "Write", toolId = "tW" }, fake_provider())
    world.apply(w, { kind = "turn_end", sessionId = "a" }, fake_provider())
    local ch = world.getCharacter(w, "a")
    assert.are.equal("waiting", ch.bubble)
    assert.is_nil(ch.activity)  -- cleared
    assert.is_true(ch.bubble_ttl > 1.9 and ch.bubble_ttl <= 2.01)
  end)

  it("tool_start after turn_end clears the waiting bubble", function()
    local w = world.new(small_layout())
    world.addCharacter(w, mk_char("a"))
    world.apply(w, { kind = "turn_end", sessionId = "a" }, fake_provider())
    assert.are.equal("waiting", world.getCharacter(w, "a").bubble)
    world.apply(w, { kind = "tool_start", sessionId = "a", toolName = "Read", toolId = "tR" }, fake_provider())
    assert.is_nil(world.getCharacter(w, "a").bubble)
  end)

  it("returns false for unknown character", function()
    local w = world.new(small_layout())
    assert.is_false(world.apply(w, { kind = "tool_start", sessionId = "ghost", toolName = "Read", toolId = "t1" }, fake_provider()))
  end)

  it("ignores unknown event kinds", function()
    local w = world.new(small_layout())
    world.addCharacter(w, mk_char("a"))
    assert.is_false(world.apply(w, { kind = "unknown", sessionId = "a" }, fake_provider()))
  end)
end)

describe("world.tick — bubble fade", function()
  it("waiting bubble disappears after ttl", function()
    local fake_provider = { toolStateMap = {}, permissionExemptTools = {} }
    local w = world.new(small_layout())
    world.addCharacter(w, mk_char("a"))
    world.apply(w, { kind = "turn_end", sessionId = "a" }, fake_provider)
    world.tick(w, 1.0, fake_provider)
    assert.are.equal("waiting", world.getCharacter(w, "a").bubble)
    world.tick(w, 1.2, fake_provider)  -- total 2.2s > 2.0s TTL
    assert.is_nil(world.getCharacter(w, "a").bubble)
  end)
end)

describe("world.tick — permission timer", function()
  local function prov()
    return {
      toolStateMap = { Bash = "type", Read = "read" },
      permissionExemptTools = { Read = true, Grep = true },
    }
  end

  it("sets permission bubble after 7s on a non-exempt tool", function()
    local w = world.new(small_layout())
    world.addCharacter(w, mk_char("a"))
    world.apply(w, { kind = "tool_start", sessionId = "a", toolName = "Bash", toolId = "t1" }, prov())
    world.tick(w, 3, prov())
    assert.is_nil(world.getCharacter(w, "a").bubble)
    world.tick(w, 4.5, prov())   -- total 7.5 > 7
    assert.are.equal("permission", world.getCharacter(w, "a").bubble)
  end)

  it("does NOT set permission bubble on an exempt tool (Read)", function()
    local w = world.new(small_layout())
    world.addCharacter(w, mk_char("a"))
    world.apply(w, { kind = "tool_start", sessionId = "a", toolName = "Read", toolId = "t1" }, prov())
    world.tick(w, 10, prov())
    assert.is_nil(world.getCharacter(w, "a").bubble)
  end)

  it("tool_end clears the permission bubble", function()
    local w = world.new(small_layout())
    world.addCharacter(w, mk_char("a"))
    world.apply(w, { kind = "tool_start", sessionId = "a", toolName = "Bash", toolId = "t1" }, prov())
    world.tick(w, 8, prov())
    assert.are.equal("permission", world.getCharacter(w, "a").bubble)
    world.apply(w, { kind = "tool_end", sessionId = "a", toolId = "t1" }, prov())
    assert.is_nil(world.getCharacter(w, "a").bubble)
  end)
end)

describe("world.tick — stale detection", function()
  local function prov()
    return { toolStateMap = {}, permissionExemptTools = {} }
  end

  it("returns ids of characters silent for > 60s", function()
    local w = world.new(small_layout())
    world.addCharacter(w, mk_char("old"))
    world.addCharacter(w, mk_char("new"))
    world.apply(w, { kind = "turn_end", sessionId = "old" }, prov())
    world.apply(w, { kind = "turn_end", sessionId = "new" }, prov())
    -- Advance 61s on both, then refresh "new"
    world.tick(w, 30, prov())
    world.apply(w, { kind = "turn_end", sessionId = "new" }, prov())
    world.tick(w, 31, prov())

    local stale = world.tick(w, 0.1, prov())
    -- Only "old" has been silent long enough.
    local stale_ids = {}
    for _, id in ipairs(stale) do stale_ids[id] = true end
    assert.is_true(stale_ids["old"] == true)
    assert.is_nil(stale_ids["new"])
  end)

  it("any event resets idle_time", function()
    local w = world.new(small_layout())
    world.addCharacter(w, mk_char("a"))
    world.apply(w, { kind = "turn_end", sessionId = "a" }, prov())
    world.tick(w, 50, prov())
    world.apply(w, { kind = "turn_end", sessionId = "a" }, prov())
    local stale = world.tick(w, 10, prov())
    assert.are.equal(0, #stale)
  end)
end)

describe("world.pickDiversePalette", function()
  it("returns 0 on empty world", function()
    local w = world.new(small_layout())
    assert.are.equal(0, world.pickDiversePalette(w))
  end)

  it("picks the lowest-index palette that is least used", function()
    local w = world.new(small_layout())
    -- palette 0 taken
    world.addCharacter(w, { id = "a", col = 0, row = 0, palette = 0 })
    assert.are.equal(1, world.pickDiversePalette(w))
    -- palette 0 and 1 taken
    world.addCharacter(w, { id = "b", col = 0, row = 0, palette = 1 })
    assert.are.equal(2, world.pickDiversePalette(w))
  end)

  it("first 6 chars get 6 distinct palettes", function()
    local w = world.new(small_layout())
    local picked = {}
    for i = 1, 6 do
      local p = world.pickDiversePalette(w)
      picked[p] = true
      world.addCharacter(w, { id = "c" .. i, col = 0, row = 0, palette = p })
    end
    for i = 0, 5 do assert.is_true(picked[i] == true) end
  end)

  it("7th character reuses a least-used palette", function()
    local w = world.new(small_layout())
    for i = 0, 5 do
      world.addCharacter(w, { id = "c" .. i, col = 0, row = 0, palette = i })
    end
    local p = world.pickDiversePalette(w)
    assert.is_true(p >= 0 and p <= 5)
  end)
end)

describe("world.removeCharacter", function()
  it("removes and reindexes remaining characters", function()
    local w = world.new(small_layout())
    world.addCharacter(w, mk_char("a"))
    world.addCharacter(w, mk_char("b"))
    world.addCharacter(w, mk_char("c"))
    world.removeCharacter(w, "b")
    assert.is_nil(world.getCharacter(w, "b"))
    assert.are.equal(1, w.char_index["a"])
    assert.are.equal(2, w.char_index["c"])
  end)

  it("releases the seat of removed character", function()
    local w = world.new(small_layout())
    world.addCharacter(w, mk_char("a"))
    world.assignSeat(w, "a", "s1")
    world.removeCharacter(w, "a")
    assert.is_nil(w.seat_occupancy["s1"])
  end)

  it("no-op on unknown id", function()
    local w = world.new(small_layout())
    world.removeCharacter(w, "ghost")
    assert.are.equal(0, #w.characters)
  end)
end)

helper.run()
