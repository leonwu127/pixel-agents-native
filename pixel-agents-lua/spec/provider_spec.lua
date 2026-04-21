package.path = "./?.lua;./?/init.lua;" .. package.path
local helper = require("spec.helper")
local provider = require("src.provider")
require("src.providers.claude")   -- registers "claude"

describe("provider.register + create", function()
  it("factory called with opts on create", function()
    local captured = nil
    provider.register("test-fixture", function(opts)
      captured = opts
      return { id = "test-fixture", value = opts.value }
    end)
    local p = provider.create("test-fixture", { value = 42 })
    assert.are.equal(42, captured.value)
    assert.are.equal(42, p.value)
  end)

  it("errors on unknown id", function()
    assert.has_error(function() provider.create("ghost") end, "unknown provider id")
  end)

  it("errors on bad register arguments", function()
    assert.has_error(function() provider.register("", function() end) end, "non-empty string")
    assert.has_error(function() provider.register("x", "not a function") end, "must be a function")
  end)

  it("has() reflects registration", function()
    assert.is_true(provider.has("claude"))
    assert.is_false(provider.has("ghost"))
  end)
end)

describe("claude provider", function()
  it("exposes core contract fields", function()
    local p = provider.create("claude")
    assert.are.equal("claude", p.id)
    assert.are.equal("Claude Code", p.displayName)
    assert.are.equal("%.jsonl$", p.sessionFilePattern)
    assert.is_not_nil(p.normalize)
    assert.is_not_nil(p.formatToolStatus)
    assert.is_not_nil(p.permissionExemptTools)
    assert.is_not_nil(p.toolStateMap)
  end)

  it("sessionDirs defaults to empty list", function()
    local p = provider.create("claude")
    local dirs = p.sessionDirs()
    assert.are.same({}, dirs)
  end)

  it("sessionDirs honors opts.session_dirs_fn", function()
    local p = provider.create("claude", {
      session_dirs_fn = function() return { "C:/fake/dir" } end,
    })
    assert.are.same({ "C:/fake/dir" }, p.sessionDirs())
  end)

  it("permissionExemptTools includes read-only tools", function()
    local p = provider.create("claude")
    assert.is_true(p.permissionExemptTools["Read"])
    assert.is_true(p.permissionExemptTools["Grep"])
    assert.is_nil(p.permissionExemptTools["Bash"])
    assert.is_nil(p.permissionExemptTools["Write"])
  end)

  it("toolStateMap maps Read/Grep to read and Write/Bash to type", function()
    local p = provider.create("claude")
    assert.are.equal("read", p.toolStateMap["Read"])
    assert.are.equal("read", p.toolStateMap["Grep"])
    assert.are.equal("type", p.toolStateMap["Write"])
    assert.are.equal("type", p.toolStateMap["Bash"])
    assert.are.equal("type", p.toolStateMap["Edit"])
  end)

  it("normalize(assistant tool_use) returns tool_start", function()
    local p = provider.create("claude")
    local line = [[{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Read","input":{"file_path":"/a.lua"}}]}}]]
    local e = p.normalize(line)
    assert.are.equal("tool_start", e.kind)
    assert.are.equal("Read", e.toolName)
  end)

  it("formatToolStatus handles Read with filepath", function()
    local p = provider.create("claude")
    assert.are.equal("Read main.lua", p.formatToolStatus("Read", { file_path = "/x/y/main.lua" }))
  end)

  it("formatToolStatus truncates long Bash commands", function()
    local p = provider.create("claude")
    local s = p.formatToolStatus("Bash", { command = string.rep("x", 100) })
    assert.is_true(#s <= 50)
    assert.is_truthy(s:find("Bash "))
  end)

  it("formatToolStatus falls back to tool name", function()
    local p = provider.create("claude")
    assert.are.equal("MysteryTool", p.formatToolStatus("MysteryTool", {}))
  end)
end)

helper.run()
