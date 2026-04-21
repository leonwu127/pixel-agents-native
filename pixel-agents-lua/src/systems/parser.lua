-- Claude Code JSONL line -> normalized event (or nil when the line is irrelevant).
-- Pure Lua; no IO; no Love2D dependency.
--
-- Input line is one JSON record (no trailing newline).
-- Session id is NOT derivable from the line; the watcher provides it.
--
-- Events returned:
--   { kind = "tool_start", toolId = <str>, toolName = <str>, input = <table|any> }
--   { kind = "tool_end",   toolId = <str> }
--   { kind = "turn_end" }
--
-- Returns nil for:
--   - empty string / nil input
--   - malformed JSON
--   - assistant record with only text blocks
--   - user record with plain-text content (a user prompt)
--   - unknown record types

local json = require("src.vendor.json")

local M = {}

local function first_tool_use(content)
  if type(content) ~= "table" then return nil end
  for _, block in ipairs(content) do
    if type(block) == "table" and block.type == "tool_use" then
      return block
    end
  end
  return nil
end

local function first_tool_result(content)
  if type(content) ~= "table" then return nil end
  for _, block in ipairs(content) do
    if type(block) == "table" and block.type == "tool_result" then
      return block
    end
  end
  return nil
end

function M.parseLine(line)
  if not line or line == "" then return nil end
  local ok, record = pcall(json.decode, line)
  if not ok or type(record) ~= "table" then return nil end

  local t = record.type

  if t == "assistant" then
    local content = record.message and record.message.content
    local tool = first_tool_use(content)
    if tool then
      return {
        kind = "tool_start",
        toolId = tool.id,
        toolName = tool.name,
        input = tool.input,
      }
    end
    return nil
  end

  if t == "user" then
    local content = record.message and record.message.content
    local result = first_tool_result(content)
    if result then
      return {
        kind = "tool_end",
        toolId = result.tool_use_id,
      }
    end
    return nil
  end

  if t == "system" and record.subtype == "turn_duration" then
    return { kind = "turn_end" }
  end

  return nil
end

return M
