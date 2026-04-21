package.path = "./?.lua;./?/init.lua;" .. package.path
local helper = require("spec.helper")
local character = require("src.entities.character")

local function pt(c, r) return { col = c, row = r } end

describe("character.new", function()
  it("sets defaults", function()
    local ch = character.new({ id = "a", col = 0, row = 5 })
    assert.are.equal("idle", ch.state)
    assert.are.equal("down", ch.direction)
    assert.are.equal(0, ch.col)
    assert.are.equal(5, ch.row)
    assert.are.equal(0, ch.x)
    assert.are.equal(5, ch.y)
  end)

  it("honors initial direction", function()
    local ch = character.new({ id = "a", col = 0, row = 0, direction = "right" })
    assert.are.equal("right", ch.direction)
  end)
end)

describe("character.walkTo", function()
  it("sets state=walk with a multi-tile path", function()
    local ch = character.new({ id = "a", col = 0, row = 0 })
    character.walkTo(ch, { pt(0, 0), pt(1, 0), pt(2, 0) })
    assert.are.equal("walk", ch.state)
    assert.are.equal(2, ch.path_idx)  -- skipped starting tile (0,0)
    assert.are.equal("right", ch.direction)
  end)

  it("stays idle if path is only current tile", function()
    local ch = character.new({ id = "a", col = 0, row = 0 })
    character.walkTo(ch, { pt(0, 0) })
    assert.are.equal("idle", ch.state)
    assert.is_nil(ch.path)
  end)

  it("no-op on empty path", function()
    local ch = character.new({ id = "a", col = 2, row = 2 })
    character.walkTo(ch, {})
    assert.are.equal("idle", ch.state)
  end)

  it("faces correctly for first path tile", function()
    local ch = character.new({ id = "a", col = 1, row = 1 })
    character.walkTo(ch, { pt(1, 1), pt(1, 0) })
    assert.are.equal("up", ch.direction)

    ch = character.new({ id = "b", col = 1, row = 1 })
    character.walkTo(ch, { pt(1, 1), pt(0, 1) })
    assert.are.equal("left", ch.direction)
  end)
end)

describe("character.update (movement)", function()
  it("advances x,y smoothly toward the next tile", function()
    local ch = character.new({ id = "a", col = 0, row = 0 })
    character.walkTo(ch, { pt(0, 0), pt(3, 0) })
    character.update(ch, 0.1)  -- WALK_SPEED 3 tiles/s * 0.1s = 0.3 tiles
    assert.is_true(ch.x > 0.25 and ch.x < 0.35)
    assert.are.equal(0, ch.col)  -- integer tile hasn't snapped yet
    assert.are.equal("walk", ch.state)
  end)

  it("snaps to target tile and continues along path", function()
    local ch = character.new({ id = "a", col = 0, row = 0 })
    character.walkTo(ch, { pt(0, 0), pt(1, 0), pt(2, 0) })
    -- Enough time to cross 1.5 tiles at 3 tiles/s → 0.5s
    character.update(ch, 0.5)
    assert.are.equal(1, ch.col)      -- crossed tile (1,0)
    assert.are.equal("walk", ch.state)
  end)

  it("reaches the end and flips to idle", function()
    local ch = character.new({ id = "a", col = 0, row = 0 })
    character.walkTo(ch, { pt(0, 0), pt(1, 0), pt(2, 0) })
    -- 10 seconds: far more than needed (needs ~0.67s at 3 t/s for 2 tiles)
    character.update(ch, 10)
    assert.are.equal("idle", ch.state)
    assert.are.equal(2, ch.col)
    assert.are.equal(0, ch.row)
    assert.is_nil(ch.path)
  end)
end)

describe("character.walkTo arrival_facing", function()
  it("overrides direction on arrival when arrival_facing given", function()
    local ch = character.new({ id = "a", col = 0, row = 0 })
    -- Path ends with a move east, so natural arrival direction would be "right"
    character.walkTo(ch, { pt(0, 0), pt(1, 0), pt(2, 0) }, { arrival_facing = "up" })
    character.update(ch, 10)
    assert.are.equal("idle", ch.state)
    assert.are.equal("up", ch.direction)
    -- Consumed, cleared for next walk
    assert.is_nil(ch.arrival_facing)
  end)

  it("respects natural direction when arrival_facing omitted", function()
    local ch = character.new({ id = "a", col = 0, row = 0 })
    character.walkTo(ch, { pt(0, 0), pt(1, 0), pt(2, 0) })
    character.update(ch, 10)
    assert.are.equal("right", ch.direction)
  end)

  it("single-tile walk (start == end) still applies arrival_facing", function()
    local ch = character.new({ id = "a", col = 0, row = 0, direction = "right" })
    character.walkTo(ch, { pt(0, 0) }, { arrival_facing = "down" })
    assert.are.equal("idle", ch.state)
    assert.are.equal("down", ch.direction)
  end)
end)

describe("character.face_toward", function()
  it("picks axis with the larger delta", function()
    local ch = character.new({ id = "a", col = 5, row = 5 })
    character.face_toward(ch, pt(5, 0))  -- large up delta
    assert.are.equal("up", ch.direction)
    character.face_toward(ch, pt(8, 5))  -- right
    assert.are.equal("right", ch.direction)
    character.face_toward(ch, pt(0, 5))  -- left
    assert.are.equal("left", ch.direction)
    character.face_toward(ch, pt(5, 10)) -- down
    assert.are.equal("down", ch.direction)
  end)
end)

describe("character.getRenderInfo", function()
  it("idle returns stand frame (walk cycle idx 2 → frame 1)", function()
    local ch = character.new({ id = "a", col = 0, row = 0 })
    local info = character.getRenderInfo(ch)
    assert.are.equal(1, info.frame)
    assert.are.equal(0, info.dir_row)   -- facing down
    assert.is_false(info.flip_x)
  end)

  it("left direction returns flip_x=true", function()
    local ch = character.new({ id = "a", col = 0, row = 0, direction = "left" })
    local info = character.getRenderInfo(ch)
    assert.are.equal(2, info.dir_row)   -- same row as right
    assert.is_true(info.flip_x)
  end)
end)

helper.run()
