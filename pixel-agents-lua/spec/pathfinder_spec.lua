package.path = "./?.lua;./?/init.lua;" .. package.path
local helper = require("spec.helper")
local pf = require("src.systems.pathfinder")

local function pt(c, r) return { col = c, row = r } end

describe("pathfinder.findPath", function()
  it("returns single-tile path when from == to", function()
    local p = pf.findPath({ size = { cols = 5, rows = 5 }, from = pt(2, 2), to = pt(2, 2) })
    assert.are.same({ pt(2, 2) }, p)
  end)

  it("finds a straight east-west path", function()
    local p = pf.findPath({ size = { cols = 5, rows = 5 }, from = pt(0, 2), to = pt(4, 2) })
    assert.is_not_nil(p)
    assert.are.equal(5, #p)
    assert.are.same(pt(0, 2), p[1])
    assert.are.same(pt(4, 2), p[5])
    -- Every step is exactly 1 tile apart (Manhattan)
    for i = 1, #p - 1 do
      local dc = math.abs(p[i].col - p[i + 1].col)
      local dr = math.abs(p[i].row - p[i + 1].row)
      assert.are.equal(1, dc + dr)
    end
  end)

  it("returns nil when start is blocked", function()
    local p = pf.findPath({
      size = { cols = 5, rows = 5 },
      blocked = { ["0,0"] = true },
      from = pt(0, 0), to = pt(2, 2),
    })
    assert.is_nil(p)
  end)

  it("returns nil when end is blocked", function()
    local p = pf.findPath({
      size = { cols = 5, rows = 5 },
      blocked = { ["4,4"] = true },
      from = pt(0, 0), to = pt(4, 4),
    })
    assert.is_nil(p)
  end)

  it("returns nil when fully walled off", function()
    local blocked = {}
    for r = 0, 4 do blocked["2," .. r] = true end
    local p = pf.findPath({
      size = { cols = 5, rows = 5 },
      blocked = blocked,
      from = pt(0, 0), to = pt(4, 4),
    })
    assert.is_nil(p)
  end)

  it("navigates around a U-shape obstacle", function()
    -- A C-shape wall forcing the path to go around:
    --   . . . . .
    --   . X X X .
    --   . X X X .
    --   . X . X .
    --   . . . . .
    -- From (2,3) must exit via col 2 row 4 (down), then go any route to (0,0).
    local blocked = {
      ["1,1"] = true, ["2,1"] = true, ["3,1"] = true,
      ["1,2"] = true, ["2,2"] = true, ["3,2"] = true,
      ["1,3"] = true, ["3,3"] = true,
    }
    local p = pf.findPath({
      size = { cols = 5, rows = 5 },
      blocked = blocked,
      from = pt(2, 3), to = pt(0, 0),
    })
    assert.is_not_nil(p)
    assert.are.same(pt(2, 3), p[1])
    assert.are.same(pt(0, 0), p[#p])
    for _, t in ipairs(p) do
      assert.is_nil(blocked[pf.key(t.col, t.row)])
    end
    -- must step through (2,4) since (1,3)(3,3) blocked and (1,2)(3,2) blocked
    local has_gap = false
    for _, t in ipairs(p) do
      if t.col == 2 and t.row == 4 then has_gap = true end
    end
    assert.is_true(has_gap)
  end)

  it("respects grid bounds", function()
    local p = pf.findPath({
      size = { cols = 3, rows = 3 },
      from = pt(0, 0), to = pt(2, 2),
    })
    assert.is_not_nil(p)
    for _, t in ipairs(p) do
      assert.is_true(t.col >= 0 and t.col < 3)
      assert.is_true(t.row >= 0 and t.row < 3)
    end
  end)
end)

describe("pathfinder.key", function()
  it("formats (col,row) consistently", function()
    assert.are.equal("5,3", pf.key(5, 3))
  end)
end)

helper.run()
