package.path = "./?.lua;./?/init.lua;" .. package.path
local helper = require("spec.helper")
local config = require("src.config")

describe("config.project_hash", function()
  it("replaces colon and backslashes with dashes (Windows)", function()
    assert.are.equal(
      "C--Users-leonw-Workspace-pixel-agents-native",
      config.project_hash("C:\\Users\\leonw\\Workspace\\pixel-agents-native"))
  end)

  it("replaces forward slashes too (POSIX-style paths)", function()
    assert.are.equal(
      "C--Users-leonw-Workspace-pixel-agents-native",
      config.project_hash("C:/Users/leonw/Workspace/pixel-agents-native"))
  end)

  it("errors on empty path", function()
    assert.has_error(function() config.project_hash("") end, "path required")
  end)

  it("errors on non-string", function()
    assert.has_error(function() config.project_hash(nil) end, "path required")
  end)
end)

describe("config.load", function()
  it("uses defaults when no config file", function()
    -- We can't easily mock find_config_file without refactoring, so use a
    -- guaranteed-absent path by temporarily pointing user_home at a bogus dir.
    local orig_home = config.user_home
    config.user_home = function() return "Z:/nope/does/not/exist" end
    local ok, c = pcall(config.load, "C:/myproject")
    config.user_home = orig_home
    assert.is_true(ok)
    assert.are.equal("C:/myproject", c.workspacePath)
    assert.are.equal("layouts/mvp_v0.lua", c.layoutFile)
    assert.are.equal(500, c.pollMs)
    assert.are.equal("C--myproject", c.projectHash)
    assert.is_truthy(c.claudeDir:find("C--myproject", 1, true))
  end)

  it("computes claudeDir with projectHash suffix", function()
    local orig_home = config.user_home
    config.user_home = function() return "X:/home/u" end
    local _, c = pcall(config.load, "C:/work")
    config.user_home = orig_home
    assert.are.equal("X:/home/u/.claude/projects/C--work", c.claudeDir)
  end)
end)

helper.run()
