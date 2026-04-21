-- Provider registry + factory.
--
-- A provider knows how to:
--   - locate session files on disk (sessionDirs() -> list of absolute dirs)
--   - filter which files are sessions (sessionFilePattern, Lua string pattern)
--   - normalize a raw JSONL line into a common AgentEvent (normalize(line) -> event | nil)
--   - format a tool call into a human label (formatToolStatus(name, input) -> string)
--   - tell which tools skip the permission timer (permissionExemptTools set)
--   - map a tool name to a character state (toolStateMap: "type" | "read")
--
-- Each provider module (providers/<id>.lua) self-registers on require.
-- Consumers: `require("src.providers.claude"); local p = provider.create("claude", opts)`.

local M = {}

M._factories = {}

function M.register(id, factory)
  if type(id) ~= "string" or #id == 0 then
    error("provider.register: id must be a non-empty string", 2)
  end
  if type(factory) ~= "function" then
    error("provider.register: factory must be a function", 2)
  end
  M._factories[id] = factory
end

function M.create(id, opts)
  local f = M._factories[id]
  if not f then
    error(string.format("provider.create: unknown provider id %q", tostring(id)), 2)
  end
  return f(opts or {})
end

function M.has(id)
  return M._factories[id] ~= nil
end

return M
