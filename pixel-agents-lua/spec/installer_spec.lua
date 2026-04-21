package.path = "./?.lua;./?/init.lua;" .. package.path
local helper = require("spec.helper")
local installer = require("src.systems.installer")
local http = require("src.systems.http")
local json_decode = require("src.vendor.json").decode

-- Use http.json_encode as the encoder so we roundtrip through what main.lua
-- will actually use. Wrap it in a json-ish table for the IO-bound helpers.
local json = { encode = http.json_encode, decode = json_decode }

local SCRIPT = "C:/Users/leonw/.pixel-agents-lua/hooks/claude-hook.ps1"

describe("installer.is_our_entry", function()
  it("matches entries that reference the hook script filename", function()
    local entry = installer.make_entry(SCRIPT)
    assert.is_true(installer.is_our_entry(entry))
  end)

  it("rejects foreign entries", function()
    assert.is_false(installer.is_our_entry({
      matcher = "",
      hooks = { { type = "command", command = "echo hi" } },
    }))
  end)

  it("rejects malformed entries", function()
    assert.is_false(installer.is_our_entry(nil))
    assert.is_false(installer.is_our_entry({}))
    assert.is_false(installer.is_our_entry({ hooks = "not a table" }))
  end)

  it("matches legacy-named entry if command contains script filename", function()
    local entry = {
      matcher = "",
      hooks = { { type = "command",
        command = 'powershell -File "C:/old/path/claude-hook.ps1"' } },
    }
    assert.is_true(installer.is_our_entry(entry))
  end)
end)

describe("installer.merge_install", function()
  it("installs entry for each HOOK_EVENT", function()
    local out = installer.merge_install({}, SCRIPT)
    for _, ev in ipairs(installer.HOOK_EVENTS) do
      assert.is_not_nil(out.hooks[ev])
      assert.are.equal(1, #out.hooks[ev])
      assert.is_true(installer.is_our_entry(out.hooks[ev][1]))
    end
  end)

  it("preserves unrelated foreign entries", function()
    local settings = {
      hooks = {
        Stop = { { matcher = "*", hooks = { { type = "command", command = "foo" } } } },
      },
    }
    local out = installer.merge_install(settings, SCRIPT)
    assert.are.equal(2, #out.hooks.Stop)
    -- Foreign entry still present
    local foreign_found = false
    for _, e in ipairs(out.hooks.Stop) do
      if not installer.is_our_entry(e) then foreign_found = true end
    end
    assert.is_true(foreign_found)
  end)

  it("is idempotent: running twice produces same result", function()
    local a = installer.merge_install({}, SCRIPT)
    local b = installer.merge_install(a, SCRIPT)
    assert.are.equal(json.encode(a), json.encode(b))
  end)

  it("replaces stale entry when script path changes", function()
    local a = installer.merge_install({}, "C:/old/claude-hook.ps1")
    local b = installer.merge_install(a, "C:/new/claude-hook.ps1")
    -- Still exactly one of our entries per event, and it uses the new path
    for _, ev in ipairs(installer.HOOK_EVENTS) do
      local ours = {}
      for _, e in ipairs(b.hooks[ev]) do
        if installer.is_our_entry(e) then ours[#ours + 1] = e end
      end
      assert.are.equal(1, #ours)
      assert.is_truthy(ours[1].hooks[1].command:find("C:/new/claude-hook.ps1", 1, true))
    end
  end)

  it("preserves top-level non-hook fields", function()
    local settings = { apiKey = "secret", theme = "dark", hooks = {} }
    local out = installer.merge_install(settings, SCRIPT)
    assert.are.equal("secret", out.apiKey)
    assert.are.equal("dark", out.theme)
  end)

  it("does not mutate the input settings table", function()
    local settings = { hooks = { Stop = {} } }
    installer.merge_install(settings, SCRIPT)
    assert.are.equal(0, #settings.hooks.Stop)
  end)
end)

describe("installer.merge_uninstall", function()
  it("removes our entries and leaves foreign ones", function()
    local settings = {
      hooks = {
        Stop = {
          { matcher = "*", hooks = { { type = "command", command = "foo" } } },
          installer.make_entry(SCRIPT),
        },
      },
    }
    local out = installer.merge_uninstall(settings)
    assert.are.equal(1, #out.hooks.Stop)
    assert.is_false(installer.is_our_entry(out.hooks.Stop[1]))
  end)

  it("deletes hooks object when empty", function()
    local settings = installer.merge_install({}, SCRIPT)
    local out = installer.merge_uninstall(settings)
    assert.is_nil(out.hooks)
  end)

  it("preserves event arrays that still have foreign entries", function()
    local settings = {
      hooks = {
        Stop = {
          { matcher = "*", hooks = { { type = "command", command = "foo" } } },
        },
      },
    }
    local out = installer.merge_uninstall(settings)
    assert.are.equal(1, #out.hooks.Stop)
  end)

  it("is safe on empty settings", function()
    local out = installer.merge_uninstall({})
    assert.is_nil(out.hooks)
  end)
end)

describe("installer.is_installed", function()
  it("false when missing hooks", function()
    assert.is_false(installer.is_installed({}))
    assert.is_false(installer.is_installed({ hooks = {} }))
  end)

  it("false when only some events are installed", function()
    local partial = installer.merge_install({}, SCRIPT)
    partial.hooks.Stop = nil
    assert.is_false(installer.is_installed(partial))
  end)

  it("true after merge_install", function()
    local out = installer.merge_install({}, SCRIPT)
    assert.is_true(installer.is_installed(out))
  end)
end)

-- Fake io_ops for install()/uninstall() integration against a virtual fs.
local function make_io()
  local fs = {}
  return fs, {
    exists = function(p) return fs[p] ~= nil end,
    read_file = function(p) return fs[p] end,
    write_file = function(p, data) fs[p] = data; return true end,
    ensure_parent_dir = function() return true end,
  }
end

describe("installer.install / uninstall (IO)", function()
  it("writes JSON settings with our hooks", function()
    local fs, io_ops = make_io()
    assert.is_true(installer.install(io_ops, json, "/fake/settings.json", SCRIPT))
    local decoded = json.decode(fs["/fake/settings.json"])
    assert.is_true(installer.is_installed(decoded))
  end)

  it("round-trip install -> uninstall restores to empty", function()
    local fs, io_ops = make_io()
    installer.install(io_ops, json, "/fake/settings.json", SCRIPT)
    installer.uninstall(io_ops, json, "/fake/settings.json")
    local decoded = json.decode(fs["/fake/settings.json"])
    assert.is_nil(decoded.hooks)
  end)

  it("install preserves existing foreign top-level fields", function()
    local fs, io_ops = make_io()
    fs["/fake/settings.json"] = '{"theme":"dark","extra":{"k":1}}'
    installer.install(io_ops, json, "/fake/settings.json", SCRIPT)
    local decoded = json.decode(fs["/fake/settings.json"])
    assert.are.equal("dark", decoded.theme)
    assert.are.equal(1, decoded.extra.k)
    assert.is_true(installer.is_installed(decoded))
  end)

  it("install is idempotent across runs", function()
    local fs, io_ops = make_io()
    installer.install(io_ops, json, "/fake/settings.json", SCRIPT)
    local first = fs["/fake/settings.json"]
    installer.install(io_ops, json, "/fake/settings.json", SCRIPT)
    local second = fs["/fake/settings.json"]
    assert.are.equal(first, second)
  end)

  it("uninstall is safe when settings.json missing", function()
    local _, io_ops = make_io()
    assert.is_true(installer.uninstall(io_ops, json, "/fake/settings.json"))
  end)
end)

helper.run()
