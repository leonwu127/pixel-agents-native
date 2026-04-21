package.path = "./?.lua;./?/init.lua;" .. package.path
local helper = require("spec.helper")
local loader = require("src.layout.loader")

local function minimal()
  return {
    size = { cols = 10, rows = 5 },
    door = { col = 0, row = 2 },
    seats = { { id = "a", col = 4, row = 2 } },
  }
end

describe("layout.loader.validate", function()
  it("accepts a minimal valid layout", function()
    local l = loader.validate(minimal())
    assert.are.equal(10, l.size.cols)
    assert.are.equal(5, l.size.rows)
    assert.are.equal(0, l.door.col)
    assert.are.equal(2, l.door.row)
    assert.are.equal("a", l.seats[1].id)
    assert.are.equal("floor_0", l.default_floor)  -- default
  end)

  it("errors on non-table input", function()
    assert.has_error(function() loader.validate("nope") end, "must be a table")
  end)

  it("errors on missing size", function()
    local raw = minimal(); raw.size = nil
    assert.has_error(function() loader.validate(raw) end, "layout.size missing")
  end)

  it("errors on zero cols", function()
    local raw = minimal(); raw.size.cols = 0
    assert.has_error(function() loader.validate(raw) end, "cols must be a positive number")
  end)

  it("errors on out-of-bounds door", function()
    local raw = minimal(); raw.door.col = 99
    assert.has_error(function() loader.validate(raw) end, "layout.door.col out of bounds")
  end)

  it("errors on empty seats", function()
    local raw = minimal(); raw.seats = {}
    assert.has_error(function() loader.validate(raw) end, "seats must be a non-empty array")
  end)

  it("errors on duplicate seat id", function()
    local raw = minimal()
    raw.seats = {
      { id = "a", col = 1, row = 2 },
      { id = "a", col = 2, row = 2 },
    }
    assert.has_error(function() loader.validate(raw) end, "duplicate seat id: a")
  end)

  it("builds walls and desks into the blocked set", function()
    local raw = minimal()
    raw.walls = { { col = 7, row = 3 } }
    raw.desks = { { col = 4, row = 1 } }
    local l = loader.validate(raw)
    assert.is_true(l.blocked["7,3"] == true)
    assert.is_true(l.blocked["4,1"] == true)
    assert.is_nil(l.blocked["0,0"])
  end)

  it("respects custom default_floor", function()
    local raw = minimal(); raw.default_floor = "floor_3"
    assert.are.equal("floor_3", loader.validate(raw).default_floor)
  end)
end)

describe("layout.loader.load", function()
  it("loads mvp_v0.lua", function()
    local l = loader.load("layouts/mvp_v0.lua")
    assert.are.equal(20, l.size.cols)
    assert.are.equal(11, l.size.rows)
    assert.are.equal(4, #l.seats)
    assert.are.equal("s1", l.seats[1].id)
    -- door is walkable (not in walls/blocked)
    assert.is_nil(l.walls["0,5"])
    assert.is_nil(l.blocked["0,5"])
    -- a sample wall tile is present
    assert.is_true(l.walls["0,0"] == true)
    -- a desk is in blocked
    assert.is_true(l.blocked["5,2"] == true)
  end)

  it("errors on missing file", function()
    assert.has_error(function() loader.load("does-not-exist.lua") end, "failed to load layout file")
  end)
end)

describe("layout.loader.tile_key", function()
  it("formats a (col,row) pair", function()
    assert.are.equal("3,7", loader.tile_key(3, 7))
  end)
end)

helper.run()
