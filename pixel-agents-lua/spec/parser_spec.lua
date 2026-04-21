package.path = "./?.lua;./?/init.lua;" .. package.path
local helper = require("spec.helper")
local parser = require("src.systems.parser")
local json = require("src.vendor.json")

describe("json.decode", function()
  it("decodes a simple object", function()
    local t = json.decode([[{"a":1,"b":"hi"}]])
    assert.are.equal(1, t.a)
    assert.are.equal("hi", t.b)
  end)

  it("decodes nested arrays and objects", function()
    local t = json.decode([[{"arr":[1,2,{"x":3}],"bool":true,"n":null}]])
    assert.are.equal(2, t.arr[2])
    assert.are.equal(3, t.arr[3].x)
    assert.is_true(t.bool)
    assert.is_nil(t.n)
  end)

  it("handles string escapes", function()
    local s = json.decode([["a\"b\\c\n"]])
    assert.are.equal("a\"b\\c\n", s)
  end)

  it("handles unicode escape", function()
    local s = json.decode([["\u00e9"]])  -- e with acute
    assert.are.equal("é", s)
  end)

  it("raises on malformed input", function()
    assert.has_error(function() json.decode("not json") end)
    assert.has_error(function() json.decode('{"a":') end)
  end)
end)

describe("parser.parseLine", function()
  it("returns nil for nil or empty", function()
    assert.is_nil(parser.parseLine(nil))
    assert.is_nil(parser.parseLine(""))
  end)

  it("returns nil for malformed JSON", function()
    assert.is_nil(parser.parseLine("not json"))
  end)

  it("parses assistant tool_use -> tool_start", function()
    local line = [[{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_1","name":"Read","input":{"file_path":"/x/main.lua"}}]}}]]
    local e = parser.parseLine(line)
    assert.are.equal("tool_start", e.kind)
    assert.are.equal("toolu_1", e.toolId)
    assert.are.equal("Read", e.toolName)
    assert.are.equal("/x/main.lua", e.input.file_path)
  end)

  it("parses user tool_result -> tool_end", function()
    local line = [[{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"toolu_1","content":"ok"}]}}]]
    local e = parser.parseLine(line)
    assert.are.equal("tool_end", e.kind)
    assert.are.equal("toolu_1", e.toolId)
  end)

  it("parses system turn_duration -> turn_end", function()
    local line = [[{"type":"system","subtype":"turn_duration","duration_ms":1200}]]
    local e = parser.parseLine(line)
    assert.are.equal("turn_end", e.kind)
  end)

  it("returns nil for plain-text user prompt (content is string)", function()
    local line = [[{"type":"user","message":{"content":"hello"}}]]
    assert.is_nil(parser.parseLine(line))
  end)

  it("returns nil for text-only assistant", function()
    local line = [[{"type":"assistant","message":{"content":[{"type":"text","text":"thinking"}]}}]]
    assert.is_nil(parser.parseLine(line))
  end)

  it("handles mixed content: text + tool_use -> tool_start from first tool_use", function()
    local line = [[{"type":"assistant","message":{"content":[{"type":"text","text":"hmm"},{"type":"tool_use","id":"t2","name":"Write","input":{"file_path":"/a/b"}}]}}]]
    local e = parser.parseLine(line)
    assert.are.equal("tool_start", e.kind)
    assert.are.equal("t2", e.toolId)
    assert.are.equal("Write", e.toolName)
  end)

  it("ignores system records with other subtypes", function()
    local line = [[{"type":"system","subtype":"file-history-snapshot","path":"/x"}]]
    assert.is_nil(parser.parseLine(line))
  end)

  it("ignores progress records (MVP defers agent_progress handling)", function()
    local line = [[{"type":"progress","data":{"type":"agent_progress"}}]]
    assert.is_nil(parser.parseLine(line))
  end)
end)

helper.run()
