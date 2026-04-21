-- End-to-end spec for Slice S2: character spawns at door, finds a path to a
-- free seat, walks it to completion, arrives at the seat tile as idle.
-- No Love2D required.

package.path = "./?.lua;./?/init.lua;" .. package.path
local helper = require("spec.helper")

local loader = require("src.layout.loader")
local world = require("src.world")
local character = require("src.entities.character")
local pathfinder = require("src.systems.pathfinder")

describe("S2 integration — walk to seat", function()
  it("character walks from door to seat 1 and ends idle at seat", function()
    local layout = loader.load("layouts/mvp_v0.lua")
    local w = world.new(layout)
    local ch = character.new({
      id = "demo",
      col = layout.door.col,
      row = layout.door.row,
    })
    world.addCharacter(w, ch)

    local seat = world.findFreeSeat(w)
    assert.is_not_nil(seat)
    assert.are.equal("s1", seat.id)

    local path = pathfinder.findPath({
      size = layout.size,
      blocked = layout.blocked,
      from = { col = ch.col, row = ch.row },
      to = { col = seat.col, row = seat.row },
    })
    assert.is_not_nil(path)
    assert.is_true(#path >= 2)   -- non-trivial

    character.walkTo(ch, path)
    world.assignSeat(w, ch.id, seat.id)
    assert.are.equal("walk", ch.state)
    assert.are.equal("demo", w.seat_occupancy[seat.id])

    -- Simulate ~10 seconds of frame updates in 60 fps slices.
    local ticks = 0
    while ch.state == "walk" and ticks < 600 do
      character.update(ch, 1 / 60)
      ticks = ticks + 1
    end

    assert.are.equal("idle", ch.state)
    assert.are.equal(seat.col, ch.col)
    assert.are.equal(seat.row, ch.row)
  end)

  it("second seat assignment after first character seated", function()
    local layout = loader.load("layouts/mvp_v0.lua")
    local w = world.new(layout)

    local a = character.new({ id = "a", col = layout.door.col, row = layout.door.row })
    world.addCharacter(w, a)
    local sa = world.findFreeSeat(w)
    world.assignSeat(w, "a", sa.id)
    assert.are.equal("s1", sa.id)

    local b = character.new({ id = "b", col = layout.door.col, row = layout.door.row })
    world.addCharacter(w, b)
    local sb = world.findFreeSeat(w)
    assert.are.equal("s2", sb.id)
  end)

  it("4 characters fill 4 seats; 5th returns no seat", function()
    local layout = loader.load("layouts/mvp_v0.lua")
    local w = world.new(layout)
    for _, id in ipairs({ "a", "b", "c", "d" }) do
      world.addCharacter(w, character.new({ id = id, col = 0, row = 5 }))
      local s = world.findFreeSeat(w)
      assert.is_not_nil(s)
      world.assignSeat(w, id, s.id)
    end
    world.addCharacter(w, character.new({ id = "e", col = 0, row = 5 }))
    assert.is_nil(world.findFreeSeat(w))
  end)
end)

helper.run()
