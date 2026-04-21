package.path = "./?.lua;./?/init.lua;" .. package.path
local helper = require("spec.helper")
local assertf = require("src.assert").assertf

describe("src.assert", function()
  describe("assertf", function()
    it("returns the value when truthy", function()
      assert.are.equal(42, assertf(42, "nope"))
    end)

    it("returns the table when truthy", function()
      local t = {}
      assert.are.equal(t, assertf(t, "nope"))
    end)

    it("errors on nil with a formatted message", function()
      assert.has_error(function()
        assertf(nil, "oops %d %s", 7, "bar")
      end, "oops 7 bar")
    end)

    it("errors on false", function()
      assert.has_error(function()
        assertf(false, "bad %s", "wolf")
      end, "bad wolf")
    end)

    it("error level points past assertf so traceback is useful", function()
      local ok, err = pcall(function() assertf(nil, "x") end)
      assert.is_false(ok)
      assert.is_truthy(string.find(tostring(err), "assert_spec.lua", 1, true))
    end)
  end)
end)

describe("spec/helper meta", function()
  it("exposes describe, it, assert globals", function()
    assert.is_not_nil(_G.describe)
    assert.is_not_nil(_G.it)
    assert.is_not_nil(_G.assert)
  end)

  it("assert.are.same compares tables deeply", function()
    assert.are.same({ a = 1, b = { c = 2 } }, { a = 1, b = { c = 2 } })
  end)

  it("assert.are.same fails when tables differ", function()
    assert.has_error(function()
      assert.are.same({ a = 1 }, { a = 2 })
    end)
  end)
end)

helper.run()
