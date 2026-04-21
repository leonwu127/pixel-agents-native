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
